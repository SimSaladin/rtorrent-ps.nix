{ fetchzip, buildPythonPackage
}:
buildPythonPackage rec {
  pname = "ProxyTypes";
  version = "0.9";

  src = fetchzip {
    url = "https://pypi.io/packages/source/P/${pname}/${pname}-${version}.zip";
    sha256 = "0j3ia8ihs5v7qiq44m9ck0l51wvfmi3irrm7y4x3w817yl9rsvqr";
  };
}
