{ fetchzip, buildPythonPackage
, six
}:
buildPythonPackage rec {
  pname = "pyrobase";
  version = "0.5.2";

  propagatedBuildInputs = [ six ];

  src = fetchzip {
    url = "https://pypi.io/packages/source/p/${pname}/${pname}-${version}.zip";
    sha256 = "12qycigjh1iwqwy3gbcw0afly8bfmx4ydw3il0x30jilny2b8v05";
  };

  doCheck = false;
}
