{ lib
, stdenv
, installShellFiles
, pyrocore
, makeWrapper
, lndir

, src
, version ? src.version
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, PYRO_CONFIG_DIR ? "${pyrocore}/lib/pyroscope"

, initRc ? null
, startScript ? null
, rtorrent
, rtorrent-magnet
, ...
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
in
stdenv.mkDerivation (fa: {
  pname = "rtorrent-ps";

  inherit version src;

  inherit PYRO_CONFIG_DIR RT_HOME RT_SOCKET;

  passthru = {
    inherit pyrocoreThis;
    inherit pyEnv;
  };

  makeWrapperArgs = lib.concatStringsSep " " ([
    "--prefix PATH : $out/bin"
    "--set-default PYRO_CONFIG_DIR ${fa.PYRO_CONFIG_DIR}"
    "--run 'export RT_HOME=\${RT_HOME-${fa.RT_HOME}}'"
    "--run 'export RT_SOCKET=\${RT_SOCKET-${fa.RT_SOCKET}}'"
  ]
  ++ lib.optional (!isNull initRc) "--set-default RT_INITRC ${initRc}/rtorrent.rc"
  );

  nativeBuildInputs = [
    lndir
    makeWrapper
    installShellFiles
    (pyEnv.python.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
  ];

  postBuild = ''
    # Build documentation
    make -C docs html man

    # Create python-pyrocore: python interpreter with the appropriate packages available.
    makeWrapper ${pyEnv.interpreter} $out/bin/python-pyrocore ${fa.makeWrapperArgs}

    # Wrappers for pyrocore python scripts
    for exe in ${pyrocoreThis}/bin/*; do
      baseName=$(basename "$exe")
      makeWrapper ${pyEnv}/bin/"$baseName" $out/bin/"$baseName" ${fa.makeWrapperArgs}
    done

    makeWrapper ${lib.getExe rtorrent-magnet} $out/bin/rtorrent-magnet ${fa.makeWrapperArgs}
  ''
  + lib.optionalString (!isNull startScript) ''
    install -Dm0755 ${lib.getExe (startScript fa)} $out/bin/${fa.pname}
  ''
  ;

  postInstall = ''
    # man page
    installManPage docs/build/man/rtorrent-ps.1

    # HTML docs
    mkdir -p $out/share/doc/rtorrent-ps/
    mv docs/build/html $out/share/doc/rtorrent-ps/

    for dir in share lib/pyroscope; do
      mkdir -p $out/$dir
      for drv in ${rtorrent} ${pyEnv}; do
        if [[ -e $drv/$dir ]]; then
          lndir $drv/$dir $out/$dir
        fi
      done
    done
  '';
})
