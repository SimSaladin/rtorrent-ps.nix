{ fetchFromGitHub
, installShellFiles
, buildPythonPackage
, setuptools
, six
, ProxyTypes
, pyrobase
, prompt_toolkit # required by rtxmlrpc REPL
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

  patches = [
    ./read_config_values_from_env.patch
    ./fix_prompt_toolkit_import.patch
  ];

  nativeBuildInputs = [ installShellFiles ];
  propagatedBuildInputs = [ setuptools ProxyTypes pyrobase prompt_toolkit ];

  postInstall = ''
    # TODO other commands; same file
    installShellCompletion --bash --cmd rtcontrol $src/src/pyrocore/data/config/bash-completion

    mkdir -p $out/share/pyroscope

    cp -r $src/src/scripts $out/share/pyroscope/scripts
    cp -r $src/docs/examples $out/share/pyroscope/examples

    cp -r $src/src/pyrocore/data/config/{color-schemes,rtorrent.d,templates} $out/share/pyroscope
    cp $src/src/pyrocore/data/config/*.{ini,py} $out/share/pyroscope
  '';

  postFixup = ''
    export pyroscope=$out/share/pyroscope
    $out/bin/pyroadmin -q --create-import "$pyroscope/rtorrent.d/*.rc"
    substitute ${./rtorrent-pyro.rc} $pyroscope/rtorrent-pyro.rc \
      --subst-var pyroscope
  '';

  doCheck = false;
}
