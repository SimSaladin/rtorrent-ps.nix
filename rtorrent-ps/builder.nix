{ lib
, fetchFromGitHub
, stdenv
, installShellFiles
, writeShellApplication
, pyrocore
, makeWrapper
, lndir
, coreutils
, dnsutils
, curl
, lsof
, rev
, hash
, rtorrentPSVersion
, rtorrent
, rtorrent-magnet
, rtorrent-config
, RT_HOME ? "$HOME/.rtorrent"
, RT_SOCKET ? "$RT_HOME/.scgi_local"
, RT_DOWNLOAD_PATH ? null
, PYRO_CONFIG_DIR ? "$RT_HOME/pyroscope"
, colorScheme ? "solarized-blue"
, initRc ? rtorrent-config.createRtorrentRC { }
}:

stdenv.mkDerivation (fa: {
  pname = "rtorrent-ps";
  version = "${rtorrent.version}";

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    inherit rev hash;
  };
  inherit PYRO_CONFIG_DIR RT_HOME RT_SOCKET;

  RT_INITRC = toString initRc;

  makeWrapperArgs = lib.concatStringsSep " " ([
    "--prefix PATH : $out/bin:${dnsutils}/bin:${curl}/bin"
    "--run 'export RT_HOME=\${RT_HOME-\"${fa.RT_HOME}\"}'"
    "--run 'export RT_SOCKET=\${RT_SOCKET-\"${fa.RT_SOCKET}\"}'"
    "--run 'export PYRO_CONFIG_DIR=\${PYRO_CONFIG_DIR:-\"${fa.PYRO_CONFIG_DIR}\"}'"
  ]
  ++ lib.optional (!isNull RT_DOWNLOAD_PATH) "--set-default RT_DOWNLOAD_PATH ${RT_DOWNLOAD_PATH}"
  );

  passthru = {
    inherit rtorrentPSVersion;
    inherit (pyrocore.passthru) pyEnv;

    startScript =
      writeShellApplication {
        name = fa.pname;
        text = ''
          mkdir -p "$PYRO_CONFIG_DIR"
          if [[ ! -e $PYRO_CONFIG_DIR/config.ini ]]; then
            echo "Writing a default pyroscope config.ini" >&2
            cp --no-preserve=mode ${pyrocore}/lib/pyroscope/config.ini "$PYRO_CONFIG_DIR/config.ini"
          fi
          if [[ ! -e $PYRO_CONFIG_DIR/color-schemes ]]; then
            mkdir -p "$PYRO_CONFIG_DIR/color-schemes"
            for f in ${pyrocore}/lib/pyroscope/color-schemes/* ${./color-schemes}/*; do
              cp --no-preserve=mode -v "$f" "$PYRO_CONFIG_DIR/color-schemes/$(basename -- "$f")"
            done
            echo ${colorScheme} > "$PYRO_CONFIG_DIR/color-schemes/.current"
          fi

          ${lib.fileContents ./start.sh}
        '';
        runtimeInputs = [ coreutils lsof ];
        runtimeEnv = {
          RT_BIN = lib.getExe rtorrent;
          RT_INITRC = initRc;
        };
      };

    rtorrentConfigString = ''
      # Load pyrocore settings
      ${pyrocore.passthru.rtorrentConfigString}
    '';
  };

  nativeBuildInputs = [
    lndir
    makeWrapper
    installShellFiles
    (fa.passthru.pyEnv.python.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
  ];

  postBuild = ''
    # Build documentation
    make -C docs html man

    # Create python-pyrocore: python interpreter with the appropriate packages available.
    # Also create wrappers for the pyrocore python scripts.
    makeWrapper ${fa.passthru.pyEnv.interpreter} $out/bin/python-pyrocore ${fa.makeWrapperArgs}
    for exe in ${pyrocore}/bin/*; do
      baseName=$(basename "$exe")
      makeWrapper ${fa.passthru.pyEnv}/bin/"$baseName" $out/bin/"$baseName" ${fa.makeWrapperArgs}
    done
    makeWrapper ${lib.getExe rtorrent-magnet} $out/bin/rtorrent-magnet ${fa.makeWrapperArgs}

    makeWrapper ${lib.getExe fa.passthru.startScript} $out/bin/${fa.pname} ${fa.makeWrapperArgs}
  ''
  ;

  postInstall = ''
    # man:rtorrent-ps(1)
    installManPage docs/build/man/rtorrent-ps.1

    # HTML docs
    mkdir -p $out/share/rtorrent-ps/
    cp -ar docs/build/html $out/share/rtorrent-ps/

    for dir in share lib/pyroscope; do
      mkdir -p $out/$dir
      for drv in ${rtorrent} ${fa.passthru.pyEnv}; do
        if [[ -e $drv/$dir ]]; then
          lndir $drv/$dir $out/$dir
        fi
      done
    done
  '';
})
