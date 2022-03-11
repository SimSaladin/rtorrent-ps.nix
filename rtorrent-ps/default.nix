{ lib
, fetchFromGitHub
, stdenvNoCC
, makeWrapper
, substituteAll
, python
, rtorrent
, pyrocore
, rtorrent-configs
, RT_HOME ? "$HOME/.rtorrent"
, RT_SOCKET ? "$RT_HOME/.scgi_local"
, RT_INITRC ? rtorrent-configs.rtorrentRc
}:

let
  ps = (import ../rtorrent-ps-src.nix { inherit fetchFromGitHub; }).default;

  cfg = rtorrent-configs;

  pyrocoreEnv = python.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  # Note: to use this script, set environment variables:
  #   RT_HOME RT_SOCKET RT_INITRC
  startScript = substituteAll {
    src = ./start.sh;
    rtorrent = "${rtorrent}/bin/rtorrent";
    postInstall = "chmod 0755 $out";
  };

  rtorrent-magnet = substituteAll {
    src = ../rtorrent-magnet;
    postInstall = "chmod 0755 $out";
  };
in

stdenvNoCC.mkDerivation rec {
  name = "rtorrent-ps";

  # NOTE: the source is referenced by the "rtorrent" derivation
  inherit (ps) version src;

  nativeBuildInputs = [ makeWrapper ];

  makeWrapperArgs = lib.concatStringsSep " " [
    "--prefix PATH : $out/bin"
    "--set-default RT_INITRC \"${RT_INITRC}\""
    "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
    "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
    "--set-default PYRO_CONFIG_DIR ${cfg.pyroConfigs}"
  ];

  installPhase = ''
    mkdir -p $out/{etc,bin}
    mkdir -p $out/share/{bash-completion/completions,applications}

    makeWrapper ${startScript} $out/bin/rtorrent-ps ${makeWrapperArgs}
    makeWrapper ${pyrocoreEnv}/bin/python $out/bin/python-pyrocore ${makeWrapperArgs}
    makeWrapper ${rtorrent-magnet} $out/bin/rtorrent-magnet ${makeWrapperArgs}
    makeWrapper ${rtorrent}/bin/rtorrent $out/bin/rtorrent-${rtorrent.version}

    # pyrocore
    for f in ${pyrocore}/bin/*; do
      makeWrapper "$f" $out/bin/$(basename "$f") ${makeWrapperArgs}
    done
    ln -st $out/share/bash-completion/completions ${pyrocore}/share/bash-completion/completions/*
    ln -st $out/share ${pyrocore}/share/pyroscope

    # .desktop
    install -Dm645 ${../rtorrent-magnet.desktop} $out/share/applications/

    # configs
    ln -s ${cfg.rtorrentRc} $out/etc/rtorrent.rc
    ln -s ${cfg.rtConfigs} $out/etc/rtorrent.d
    ln -s ${cfg.pyroConfigs} $out/etc/pyroscope
  '';
}
