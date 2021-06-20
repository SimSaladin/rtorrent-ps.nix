{ fetchFromGitHub
, buildPythonPackage
, python
, ProxyTypes
, pyrobase
, setuptools
}:
buildPythonPackage rec {
  pname = "pyrocore";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "pyrocore";
    rev = "9d8737d96ccb75abcc1af313cde7b8278b9d83bb";
    sha256 = "0k79d4gkvi7k6pn0xid3qq8vhr5fm4gqqq2c68816q9x143cn75v";
  };

  propagatedBuildInputs = [ setuptools ProxyTypes pyrobase ];

  postInstall = ''
    ln -nfs ${python}/bin/python $out/bin/python-pyrocore

    mkdir -p $out/share/pyroscope

    cp -r $src/src/pyrocore/data/config/* $out/share/pyroscope
    cp -r $src/src/scripts $out/share/pyroscope/scripts
    cp -r $src/docs/examples $out/share/pyroscope/examples
  '';

  postFixup = ''
    $out/bin/pyroadmin -q --create-import "$out/share/pyroscope/rtorrent.d/*.rc"
    substitute ${./rtorrent-pyro.rc} $out/share/pyroscope/rtorrent-pyro.rc \
      --subst-var out
  '';

  doCheck = false;
}
