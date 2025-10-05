{ lib
, stdenv
, installShellFiles
, writeShellApplication
, makeWrapper
, coreutils
, lsof
, lndir

, rtorrent-magnet
, rtorrent-config
, rtorrent
, pyrocore
, ps ? rtorrent.ps
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, pyroConfigDir ? "${pyrocore}/lib/pyroscope"
, colorScheme ? "solarized-blue"
}:

let
  pyrocoreThis = pyrocore.override {
    makeWrapperArgs = [
      "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
      "--set-default PYRO_CONFIG_DIR $out/lib/pyroscope"
    ];
  };

  inherit (pyrocoreThis.passthru) pyEnv;

  rtorrent-ps = stdenv.mkDerivation (fa: {
    pname = "rtorrent-ps";
    version = "${ps.version}+${rtorrent.version}";

    src = ps;

    inherit pyroConfigDir RT_HOME RT_SOCKET;

    initRc = rtorrent-config.createRtorrentRC {
      inherit colorScheme;
      extraConfig = ''
        ui.color.odd.set = "on 0"
        ui.color.even.set = ""
      '';
    };

    makeWrapperArgs = lib.concatStringsSep " " [
      "--prefix PATH : $out/bin"
      "--set-default PYRO_CONFIG_DIR ${fa.pyroConfigDir}"
      "--set-default RT_INITRC ${fa.initRc}/rtorrent.rc"
      "--run 'export RT_HOME=\${RT_HOME-${fa.RT_HOME}}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-${fa.RT_SOCKET}}'"
    ];

    startScript = writeShellApplication {
      name = fa.pname;
      text = ''
        export RT_HOME=''${RT_HOME-${fa.RT_HOME}}
        export RT_SOCKET=''${RT_SOCKET-${fa.RT_SOCKET}}
        ${builtins.readFile ./start.sh}
      '';
      runtimeInputs = [ coreutils lsof ];
      runtimeEnv = {
        RT_BIN = lib.getExe rtorrent;
        RT_INITRC = fa.initRc + "/rtorrent.rc";
        PYRO_CONFIG_DIR = fa.pyroConfigDir;
      };
    };

    nativeBuildInputs = [
      lndir
      makeWrapper
      installShellFiles
      (pyEnv.python.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
    ];

    postBuild = ''
      install -Dm0755 ${lib.getExe fa.startScript} $out/bin/${fa.pname}

      makeWrapper ${lib.getExe fa.finalPackage.rtorrentMagnet} $out/bin/rtorrent-magnet ${fa.makeWrapperArgs}

      makeWrapper ${lib.getExe rtorrent} $out/bin/rtorrent ${fa.makeWrapperArgs}

      # Create python-pyrocore: python interpreter with the appropriate packages available.
      makeWrapper ${pyEnv.interpreter} $out/bin/python-pyrocore ${fa.makeWrapperArgs}

      # Wrappers for pyrocore python scripts
      for exe in ${pyrocoreThis}/bin/*; do
        baseName=$(basename "$exe")
        makeWrapper ${pyEnv}/bin/"$baseName" $out/bin/"$baseName" ${fa.makeWrapperArgs}
      done

      # Build documentation
      make -C docs html man
    '';

    postInstall = ''
      # man page
      installManPage docs/build/man/rtorrent-ps.1

      # HTML docs
      mkdir -p $out/share/doc/rtorrent-ps/
      mv docs/build/html $out/share/doc/rtorrent-ps/

      for dir in share lib/pyroscope; do
        mkdir -p $out/$dir
        for drv in ${pyEnv} ${rtorrent}; do
          if [[ -e $drv/$dir ]]; then
            lndir $drv/$dir $out/$dir
          fi
        done
      done
    '';

    passthru = {
      inherit (fa) initRc;
      rtorrentMagnet = rtorrent-magnet.overrideAttrs { };
    };
  });

in
  rtorrent-ps
