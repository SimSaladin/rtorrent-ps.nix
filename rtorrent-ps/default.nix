{ fetchFromGitHub
, writeScriptBin
, stdenvNoCC
, makeWrapper
, runCommand
, rtorrent
, pyrocore
, python
, rtorrent-configs
, RT_HOME ? null
, RT_SOCKET ? null # "${RT_HOME}/.scgi_local"
, RT_INITRC ? null # rtorrent-configs.rtorrentRc
}:

let
  pyrocoreEnv = python.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  rtHome =
    if !builtins.isNull RT_HOME then RT_HOME
    else if builtins.getEnv "HOME" != "" then builtins.getEnv "HOME" + "/.rtorrent"
    else
      throw ''
        Could not figure out a suitable value for RT_HOME. Pass it as an
        argument or build with --impure.
      '';

  rtSocket = if builtins.isNull RT_SOCKET then "${rtHome}/.scgi_local" else RT_SOCKET;

  cfg = rtorrent-configs.override { inherit rtSocket; };

  rtorrent-magnet = writeScriptBin "rtorrent-magnet" "${../rtorrent-magnet}";
in

stdenvNoCC.mkDerivation {
  name = "rtorrent-ps";
  version = "PS-1.1-67-g244a4e9"; # git describe --long --tags

  # NOTE: the source is referenced by the "rtorrent" derivation
  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0"; # PS-1.1-66-gbac90aa
    sha256 = "1pbh18f0vhzndinrwj931lggdn0lngp7i2admsj9chpw6acs3v42";
  };

  nativeBuildInputs = [ makeWrapper ];

  RT_HOME = rtHome;
  RT_SOCKET = rtSocket;
  RT_INITRC = if builtins.isNull RT_INITRC then cfg.rtorrentRc else RT_INITRC;
  PYRO_CONFIG_DIR = "${cfg.pyroConfigs}";

  installPhase = ''
    mkdir -p $out/{etc,bin}
    mkdir -p $out/share/{bash-completion,applications}

    # Create bin/rtorrent-<ver>
    makeWrapper ${rtorrent}/bin/rtorrent $out/bin/rtorrent-${rtorrent.version}

    # Create rtorrent-magnet
    ln -s ${rtorrent-magnet}/bin/* $out/bin/
    install -Dm645 ${../rtorrent-magnet.desktop} $out/share/applications/

    # Create pyroscope executables
    for f in ${pyrocore}/bin/*; do
      makeWrapper "$f" $out/bin/$(basename "$f") \
        --set PYRO_CONFIG_DIR "$PYRO_CONFIG_DIR"
    done

    # Create bin/python-pyrocore
    makeWrapper ${pyrocoreEnv}/bin/python $out/bin/python-pyrocore \
        --set PYRO_CONFIG_DIR "$PYRO_CONFIG_DIR"

    # Create bin/rtorrent-ps
    makeWrapper ${cfg.startScript} $out/bin/rtorrent-ps \
      --prefix PATH : "$out/bin" \
      --set RT_HOME "$RT_HOME" \
      --set RT_SOCKET "$RT_SOCKET" \
      --set RT_INITRC "$RT_INITRC" \
      --set PYRO_CONFIG_DIR "$PYRO_CONFIG_DIR"

    # Add shell completion
    ln -s ${pyrocore}/share/bash-completion/* $out/share/bash-completion/

    # Create links to config files
    ln -s ${cfg.rtorrentRc} $out/etc/rtorrent.rc
    ln -s ${cfg.rtConfigs} $out/etc/rtorrent.d
    ln -s ${cfg.pyroConfigs} $out/etc/pyroscope
  '';
}
