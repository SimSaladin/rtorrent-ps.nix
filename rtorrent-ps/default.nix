{ fetchFromGitHub, stdenvNoCC, makeWrapper, runCommand
, rtorrent, pyrocore
, python
, RT_HOME
}:
let
  rtorrent-configs = runCommand "rtorrent.d" {} ''
    mkdir -p $out/rtorrent.d

    # rtorrent.rc
    cp ${../rtorrent.rc} $out/rtorrent.rc

    # rtorrent.d
    cp -r ${../rtorrent.d}/* $out/rtorrent.d

    # rtorrent.d/.import.rc
    ${pyrocore}/bin/pyroadmin -q --create-import "$out/rtorrent.d/*.rc"

    for file in $out/*.rc $out/*/*.rc; do
      substituteInPlace "$file" \
        --subst-var-by pyroscope   ${pyrocore} \
        --subst-var-by confdir     $out/rtorrent.d \
        --subst-var-by scgi_socket ${RT_HOME}/.scgi_local
    done

    # pyroscope
    mkdir -p $out/pyroscope
    # include defaults
    cp -r ${pyrocore}/share/pyroscope/color-schemes $out/pyroscope/
    # nix customizations
    substitute ${../config.ini} $out/pyroscope/config.ini \
      --subst-var-by pyroscope ${pyrocore}/share/pyroscope \
      --subst-var-by rtorrent_rc $out/rtorrent.rc
  '';

  pyrocoreEnv = python.buildEnv.override {
    extraLibs = [ pyrocore ]; # python.withPackages (ps: with ps; [ pyrocore ]);
    ignoreCollisions = true;
  };
in

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

  installPhase = ''
    mkdir -p $out/bin

    substitute ${./start.sh} $out/bin/rtorrent-ps \
      --subst-var-by basedir ${RT_HOME} \
      --subst-var-by rtorrent ${rtorrent} \
      --subst-var-by rtorrent_rc ${rtorrent-configs}/rtorrent.rc
    chmod 0755 $out/bin/rtorrent-ps

    for f in ${pyrocore}/bin/*; do
      makeWrapper "$f" $out/bin/$(basename "$f") \
        --set PYRO_CONFIG_DIR ${rtorrent-configs}/pyroscope
    done

    makeWrapper ${pyrocoreEnv}/bin/python $out/bin/python-pyrocore \
        --set PYRO_CONFIG_DIR ${rtorrent-configs}/pyroscope

  '';
}
