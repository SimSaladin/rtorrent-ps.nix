{ lib
, symlinkJoin
, fetchFromGitHub
, stdenvNoCC
, runCommandNoCC
, makeWrapper
, substituteAll
, rtorrent
, pyrocore
, pyrocoreEnv
, rtorrent-configs
, RT_HOME ? "$HOME/.rtorrent"
, RT_SOCKET ? "$RT_HOME/.scgi_local"
, RT_INITRC ? rtorrent-configs.rtorrentRc
}:

let
  ps = (import ../rtorrent-ps-src.nix { inherit fetchFromGitHub; }).default;

  cfg = rtorrent-configs;

  startScript = runCommandNoCC "rtorrent-ps-start" { src = ./start.sh; } ''
    install -Dm0755 $src $out/bin/rtorrent-ps
    patchShebangs $out
  '';

  rtorrent-magnet = runCommandNoCC "rtorrent-magnet" { src = ../rtorrent-magnet; } ''
    install -Dm0755 $src $out/bin/rtorrent-magnet
    patchShebangs $out
  '';

  configs = runCommandNoCC "rtorrent-configs" { } ''
    mkdir -p $out/etc
    ln -s ${cfg.rtorrentRc} $out/etc/rtorrent.rc
    ln -s ${cfg.rtConfigs} $out/etc/rtorrent.d
    ln -s ${cfg.pyroConfigs} $out/etc/pyroscope
  '';

in
symlinkJoin rec {
  name = "rtorrent-ps";

  paths = [
    configs
    startScript
    rtorrent-magnet
    rtorrent
    pyrocore
  ];

  nativeBuildInputs = [ makeWrapper ];

  makeWrapperArgs = lib.concatStringsSep " " [
    "--prefix PATH : $out/bin"
    "--set-default RT_BIN ${rtorrent}/bin/rtorrent"
    "--set-default RT_INITRC \"${RT_INITRC}\""
    "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
    "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
    "--set-default PYRO_CONFIG_DIR ${cfg.pyroConfigs}"
  ];

  postBuild = ''
    rm -rf $out/{EGG-INFO,lib,nix-support}

    for f in $out/bin/*; do
      wrapProgram "$f" ${makeWrapperArgs}
    done

    makeWrapper ${pyrocoreEnv.interpreter} $out/bin/python-pyrocore ${makeWrapperArgs}
    makeWrapper ${rtorrent}/bin/rtorrent $out/bin/rtorrent-${rtorrent.version}

    patchShebangs $out/bin

    install -Dm0644 ${../rtorrent-ps.1} $out/share/man/man1/rtorrent-ps.1
  '';
}
