{ fetchFromGitHub
, stdenvNoCC
, makeWrapper
, runCommand
, rtorrent
, pyrocore
, python
, RT_HOME
, rtorrent-configs
}:
let
  pyrocoreEnv = python.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };
in

# - bin/rtorrent-ps (start script)
# - ${pyrocore}/bin/* (utility programs)
# - python-pyrocore (python interpreter)

stdenvNoCC.mkDerivation {
  name = "rtorrent-ps";
  version = "PS-1.1-67-g244a4e9"; # git describe --long --tags

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0"; # PS-1.1-66-gbac90aa
    sha256 = "1pbh18f0vhzndinrwj931lggdn0lngp7i2admsj9chpw6acs3v42";
  };

  nativeBuildInputs = [ makeWrapper ];

  inherit RT_HOME;
  RT_SOCKET = "${RT_HOME}/.scgi_local";
  RTORRENT_RC = "${rtorrent-configs}/rtorrent.rc";
  PYRO_CONFIG_DIR = "${rtorrent-configs}/pyroscope";

  installPhase = ''
    mkdir -p $out/{etc,bin,share/bash-completion}

    # Create bin/rtorrent-ps
    substitute ${./start.sh} $out/bin/rtorrent-ps \
      --subst-var RT_HOME \
      --subst-var RT_SOCKET \
      --subst-var RTORRENT_RC \
      --subst-var-by rtorrent ${rtorrent}/bin/rtorrent
    chmod 0755 $out/bin/rtorrent-ps

    # Create bin/rtorrent-<ver>
    makeWrapper ${rtorrent}/bin/rtorrent $out/bin/rtorrent-${rtorrent.version}

    # Create pyroscope executables
    for f in ${pyrocore}/bin/*; do
      makeWrapper "$f" $out/bin/$(basename "$f") \
        --set PYRO_CONFIG_DIR "$PYRO_CONFIG_DIR"
    done
    ln -s ${pyrocore}/share/bash-completion/* $out/share/bash-completion/

    # Create bin/python-pyrocore
    makeWrapper ${pyrocoreEnv}/bin/python $out/bin/python-pyrocore \
        --set PYRO_CONFIG_DIR "$PYRO_CONFIG_DIR"

    # Create links to config files
    ln -st $out/etc ${rtorrent-configs}/*
  '';
}
