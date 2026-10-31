{ lib
, stdenv
, installShellFiles
, writeShellApplication
, pyrocore
, makeWrapper
, lndir
, coreutils
, lsof
, src
, rtorrentPSVersion
, rtorrent
, rtorrent-magnet
, rtorrent-config
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, PYRO_CONFIG_DIR ? "${pyrocore}/lib/pyroscope"
, colorScheme ? "solarized-blue"
, extraConfig ? ''
        ui.color.odd.set = "on 0"
        ui.color.even.set = ""
      ''
, initRc ? rtorrent-config.createRtorrentRC {
  inherit colorScheme extraConfig;
}
}:

stdenv.mkDerivation (fa: {
  pname = "rtorrent-ps";
  version = "${rtorrentPSVersion}+${rtorrent.version}";

  inherit src initRc;
  inherit PYRO_CONFIG_DIR RT_HOME RT_SOCKET;

  RT_INITRC = fa.initRc + "/rtorrent.rc";

  makeWrapperArgs = lib.concatStringsSep " " [
    "--prefix PATH : $out/bin"
    "--set-default PYRO_CONFIG_DIR ${fa.PYRO_CONFIG_DIR}"
    "--run 'export RT_HOME=\${RT_HOME-${fa.RT_HOME}}'"
    "--run 'export RT_SOCKET=\${RT_SOCKET-${fa.RT_SOCKET}}'"
    "--set-default RT_INITRC ${fa.RT_INITRC}"
  ];

  pyrocoreThis = pyrocore.override {
    makeWrapperArgs = [
      "--prefix PATH : $out/bin"
      "--run 'export RT_HOME=\${RT_HOME-${fa.RT_HOME}}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-${fa.RT_SOCKET}}'"
      "--set-default RT_INITRC ${fa.RT_INITRC}"
    ];
  };

  inherit (fa.pyrocoreThis.passthru) pyEnv;

  startScript =
    writeShellApplication {
      name = fa.pname;
      text = builtins.readFile ./start.sh;
      runtimeInputs = [ coreutils lsof ];
      runtimeEnv = {
        RT_BIN = lib.getExe rtorrent;
        inherit (fa) PYRO_CONFIG_DIR RT_INITRC;
      };
    };

  nativeBuildInputs = [
    lndir
    makeWrapper
    installShellFiles
    (fa.pyEnv.python.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
  ];

  postBuild = ''
    # Build documentation
    make -C docs html man

    # Create python-pyrocore: python interpreter with the appropriate packages available.
    # Also create wrappers for the pyrocore python scripts.
    makeWrapper ${fa.pyEnv.interpreter} $out/bin/python-pyrocore ${fa.makeWrapperArgs}
    for exe in ${fa.pyrocoreThis}/bin/*; do
      baseName=$(basename "$exe")
      makeWrapper ${fa.pyEnv}/bin/"$baseName" $out/bin/"$baseName" ${fa.makeWrapperArgs}
    done
    makeWrapper ${lib.getExe rtorrent-magnet} $out/bin/rtorrent-magnet ${fa.makeWrapperArgs}
    makeWrapper ${lib.getExe fa.startScript} $out/bin/${fa.pname} ${fa.makeWrapperArgs}
  ''
  ;

  postInstall = ''
    # man:rtorrent-ps(1)
    installManPage docs/build/man/rtorrent-ps.1

    # HTML docs
    mkdir -p $out/share/doc/rtorrent-ps/
    cp -ar docs/build/html $out/share/doc/rtorrent-ps/

    for dir in share lib/pyroscope; do
      mkdir -p $out/$dir
      for drv in ${rtorrent} ${fa.pyEnv}; do
        if [[ -e $drv/$dir ]]; then
          lndir $drv/$dir $out/$dir
        fi
      done
    done
  '';

  passthru = {
    inherit rtorrentPSVersion;
  };
})
