{ lib
, stdenv
, symlinkJoin
, substituteAll
, installShellFiles
, writeShellApplication
, makeWrapper
, coreutils
, lsof
, py2
, rtorrent
, pyrocore
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, callPackage
}:

let
  src = srcs.latest;
  srcs = callPackage ../rtorrent-ps-src.nix { };

  # PyroScope configuration (default)
  pyroscope = "${pyrocore}/lib/pyroscope";

  # The initial rtorrent.rc to load. It imports other configs.
  initRc = substituteAll {
    src = ./main.rtorrent.rc;
    inherit pyroscope;
    rtConfigs = pyrocore.passthru.createImport {
      src = ../config/rtorrent.d;
      inherit pyroscope;
    };
  };

  startScript = writeShellApplication {
    name = "rtorrent-ps";
    text = builtins.readFile ./start.sh;
    runtimeInputs = [ coreutils rtorrent lsof ];
  };

  rtorrent-magnet = writeShellApplication {
    name = "rtorrent-magnet";
    text = builtins.readFile ../misc/rtorrent-magnet;
  };

  rtorrent-ps-unwrapped = stdenv.mkDerivation {
    pname = "rtorrent-ps";
    version = src.version;

    src = src.src;

    nativeBuildInputs = [
      makeWrapper
      installShellFiles
      (py2.withPackages (ps: with ps; [
        sphinx
        sphinx_rtd_theme
      ]))
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

  pyrocoreEnv = py2.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  rtorrent-ps = symlinkJoin rec {
    name = "rtorrent-ps-${rtorrent.version}";

    paths = [
      startScript
      rtorrent-ps-unwrapped
      rtorrent-magnet
      pyrocore
      rtorrent
    ];

    makeWrapperArgs = lib.concatStringsSep " " [
      "--prefix PATH : $out/bin"
      "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
      "--set-default RT_INITRC ${initRc}"
      "--set-default PYRO_CONFIG_DIR ${pyroscope}"
    ];

    nativeBuildInputs = [ makeWrapper ];

    postBuild = ''
      rm -rf $out/EGG-INFO

      # Wrap executables with the proper environment
      for exe in $out/bin/*; do
        wrapProgram "$exe" ${makeWrapperArgs}
      done

      # A python interpreter with the appropriate packages available
      makeWrapper ${pyrocoreEnv.interpreter} $out/bin/python-pyrocore ${makeWrapperArgs}
    '';
  };

in
  rtorrent-ps
