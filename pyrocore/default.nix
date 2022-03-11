{ fetchFromGitHub
, installShellFiles
, buildPythonPackage
, ProxyTypes
, prompt_toolkit # required by rtxmlrpc REPL
, pyrobase
, requests
, setuptools
, six
, tempita
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
  propagatedBuildInputs = [
    ProxyTypes
    prompt_toolkit
    pyrobase
    requests
    setuptools
    tempita
  ];

  postInstall = ''
    installShellCompletion --bash --cmd rtcontrol $src/src/pyrocore/data/config/bash-completion
    for f in rtxmlrpc pyroadmin chtor lstor hashcheck mktor rtevent rtmv; do
      ln -s rtcontrol.bash $out/share/bash-completion/completions/$f.bash
    done

    mkdir -p $out/share/doc/pyroscope
    cp -rt $out/share/doc/pyroscope $src/docs/examples $src/src/scripts
  '';

  doCheck = false;
}
