{ lib
, fetchFromGitHub
, stdenv
, installShellFiles
, writeShellApplication
, makeWrapper

, rev
, hash

, lndir
, coreutils
, dnsutils
, curl
, lsof
, pyrocore
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

let
  pyroPyEnv = pyrocore.passthru.pyEnv;

  rtorrentConfigString = ''
    # Load pyrocore settings
    ${pyrocore.passthru.rtorrentConfigString}
  '';

  startScript = out: writeShellApplication {
    name = "rtorrent-ps";
    text = ''
      export RT_HOME=''${RT_HOME-"${RT_HOME}"}
      export RT_SOCKET=''${RT_SOCKET-"${RT_SOCKET}"}
      export PYRO_CONFIG_DIR=''${PYRO_CONFIG_DIR:-"${PYRO_CONFIG_DIR}"}
      ${lib.optionalString (!isNull RT_DOWNLOAD_PATH) ''export RT_DOWNLOAD_PATH=''${RT_DOWNLOAD_PATH:-"${RT_DOWNLOAD_PATH}"}''}
      export PATH="${out}/bin:$PATH"

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
    runtimeInputs = [
      coreutils
      lsof
      dnsutils
      curl
    ];
    runtimeEnv = {
      RT_BIN = lib.getExe rtorrent;
      RT_INITRC = toString initRc;
    };
  };
in

stdenv.mkDerivation (fa: {
  pname = "rtorrent-ps";
  inherit (rtorrent) version;

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    inherit rev hash;
  };

  nativeBuildInputs = [
    lndir
    makeWrapper
    installShellFiles
    (pyroPyEnv.python.withPackages (
      ps: with ps; [
        sphinx
        sphinx_rtd_theme
      ]
    ))
  ];

  makeWrapperArgs = lib.concatStringsSep " " (
    [
      "--prefix PATH : $out/bin:${dnsutils}/bin:${curl}/bin"
      "--run 'export RT_HOME=\${RT_HOME-\"${RT_HOME}\"}'"
      "--run 'export RT_SOCKET=\${RT_SOCKET-\"${RT_SOCKET}\"}'"
      "--run 'export PYRO_CONFIG_DIR=\${PYRO_CONFIG_DIR:-\"${PYRO_CONFIG_DIR}\"}'"
    ]
    ++ lib.optional (!isNull RT_DOWNLOAD_PATH) "--set-default RT_DOWNLOAD_PATH ${RT_DOWNLOAD_PATH}"
  );

  postBuild = ''
    # Build documentation
    make -C docs html man

    # Create python-pyrocore: python interpreter with the appropriate packages available.
    # Also create wrappers for the pyrocore python scripts.
    makeWrapper ${pyroPyEnv.interpreter}      $out/bin/python-pyrocore ${fa.makeWrapperArgs}
    makeWrapper ${lib.getExe rtorrent-magnet} $out/bin/rtorrent-magnet ${fa.makeWrapperArgs}
    for exe in ${pyrocore}/bin/*; do
      baseName=$(basename "$exe")
      makeWrapper ${pyroPyEnv}/bin/"$baseName" $out/bin/"$baseName" ${fa.makeWrapperArgs}
    done

    install -m0755 ${lib.getExe (startScript "@out@")} $out/bin/${fa.pname}
    substituteInPlace $out/bin/${fa.pname} --replace-fail @out@ ${lib.placeholder "out"}
  '';

  postInstall = ''
    # man:rtorrent-ps(1)
    installManPage docs/build/man/rtorrent-ps.1
    # HTML docs
    mkdir -p $out/share/rtorrent-ps/
    cp -ar docs/build/html $out/share/rtorrent-ps/
    for dir in share lib/pyroscope; do
      mkdir -p $out/$dir
      for drv in ${rtorrent} ${pyroPyEnv}; do
        if [[ -e $drv/$dir ]]; then
          lndir $drv/$dir $out/$dir
        fi
      done
    done
  '';

  passthru = {

    inherit
      rtorrentPSVersion
      rtorrentConfigString
      pyroPyEnv
      ;
  };

})
