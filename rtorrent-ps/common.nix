{ lib
, stdenv
, replaceVarsWith
, runCommand
, symlinkJoin
, buildEnv
, installShellFiles
, writeShellApplication
, makeWrapper
, coreutils
, lsof
, rtorrent-ps-src
, rtorrent-magnet
, rtorrent
, pyrocore
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
}:

let
  inherit (pyrocore.passthru) pyEnv createImport;

  # PyroScope configuration (default)
  pyroscope = "${pyrocore}/lib/pyroscope";

  startScript = writeShellApplication {
    name = "rtorrent-ps";
    text = builtins.readFile ./start.sh;
    runtimeInputs = [ coreutils rtorrent lsof ];
  };

  initRc = generateMainRC {
    colorScheme = "solarized-blue";
  };

  # Create the initial rtorrent.d which is will be loaded by main rtorrent.rc
  generateMainRC =
    { pyroBaseDir ? pyroscope
    , colorScheme ? "default-16"
    , extraConfig ? ""
    }:
    let
      mainConfigDirImportRC = createImport {
        src = ./templates/rtorrent.d;
        rtorrentPyroImportRC = "${pyroBaseDir}/rtorrent-pyro.rc";
      };

      mainRC = replaceVarsWith rec {
        src = ./templates/main.rtorrent.rc;
        replacements = {
          inherit mainConfigDirImportRC extraConfig;
          colorSchemeRC = "${pyroBaseDir}/color-schemes/${colorScheme}.rc";
        };
        postCheck = ''
          if [[ ! -e ${replacements.colorSchemeRC} ]]; then
            echo "error: importable file $colorSchemeRC was not found!" >&2
            exit 1
          fi
        '';
      };
    in runCommand "rtorrent-configs" { } ''
      mkdir -p $out
      # link pyroscope initial configs to output
      ln -s ${pyroBaseDir} $out/pyroscope
      # link our main rtorrent.rc
      ln -s ${mainRC} $out/rtorrent.rc
      # link our rtorrent.d
      ln -sn ${builtins.dirOf mainConfigDirImportRC} $out/rtorrent.d
    '';

  rtorrent-ps-unwrapped = stdenv.mkDerivation {
    pname = "rtorrent-ps-unwrapped";
    inherit (rtorrent-ps-src) version src;

    nativeBuildInputs = [
      makeWrapper
      installShellFiles
      (pyEnv.python.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
    ];

    postBuild = ''
      # Build documentation
      make -C docs html man
    '';

    postInstall = ''
      # man page
      installManPage docs/build/man/rtorrent-ps.1

      # HTML docs
      mkdir -p $out/share/doc/rtorrent-ps/
      mv docs/build/html $out/share/doc/rtorrent-ps/
    '';
  };

  # The final "rtorrent-ps" package is actually the relevant derivations
  # smashed together into a single derivation with additional configuration
  # baked in (mostly in the form of wrappers for the relevant executables).
  self = symlinkJoin rec {
    pname = "rtorrent-ps";
    # The rtorrent version already contains the PS version suffix
    version = rtorrent.version;

    paths = [
      startScript
      rtorrent-magnet
      rtorrent
      rtorrent-ps-unwrapped
      (buildEnv {
        name = "pyrocore-python-env";
        paths = [ pyEnv ];
        pathsToLink = [ "/lib/pyroscope" "/share" ];
      })
    ];

    nativeBuildInputs = [ makeWrapper ];

    makeWrapperArgs = lib.concatStringsSep " " [
      "--prefix PATH : $out/bin"
      "--set-default PYRO_CONFIG_DIR ${pyroscope}"
      "--set-default RT_INITRC ${initRc}/rtorrent.rc"
      "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
    ];

    postBuild = ''
      # Wrap executables with the proper environment
      for exe in $out/bin/*; do
        wrapProgram "$exe" ${makeWrapperArgs}
      done

      # Wrappers for pyrocore python scripts
      for exe in ${pyrocore}/bin/*; do
        baseName=$(basename "$exe")
        makeWrapper ${pyEnv}/bin/"$baseName" $out/bin/"$baseName" ${makeWrapperArgs}
      done

      # Create python-pyrocore: python interpreter with the appropriate packages available.
      makeWrapper ${pyEnv.interpreter} $out/bin/python-pyrocore ${makeWrapperArgs}
    '';

    passthru = {
      inherit rtorrent-ps-unwrapped startScript initRc generateMainRC;
    };

  };
in
self
