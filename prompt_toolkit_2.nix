{ buildPythonPackage
, six
, wcwidth
}:
buildPythonPackage rec {
  pname = "prompt_toolkit";
  version = "2.0.10";

  src = builtins.fetchTarball {
    url = "https://pypi.io/packages/source/p/${pname}/${pname}-${version}.tar.gz";
    sha256 = "1zja8v6mzydwsb0n8nz1yz2bx231ybb4h9dfqkvjxmixg0sm3jdg";
  };

  propagatedBuildInputs = [ six wcwidth ];
}
