{ buildPythonPackage
, setuptools
, prompt-toolkit
, requests
, tempita
, ProxyTypes
, pyrobase
, installShellFiles

, fetchFromGitHub

, makeWrapperArgs ? [ ]
, passthru ? { }
}:
buildPythonPackage {
  pname = "pyrocore";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "pyrocore";
    rev = "9d8737d96ccb75abcc1af313cde7b8278b9d83bb";
    hash = "sha256-uxzLBgk9YRMQMkxgjB+prmS4EcajxQ7sNfPEPR9p6Uw=";
  };

  inherit makeWrapperArgs passthru;

  patches = [
    ./patches/read_config_values_from_env.patch
    ./patches/rtxmlrpc-history-file.patch
    ./fake-argument-fix.patch
    # Should not be applied when prompt-toolkit is sufficiently old (lol)
    #./patches/fix_prompt_toolkit_import.patch
  ];

  nativeBuildInputs = [ installShellFiles ];

  propagatedBuildInputs = [
    setuptools
    prompt-toolkit
    requests
    tempita
    ProxyTypes
    pyrobase
  ];

  doCheck = false;

  postInstall = ''
    # Install shell completion
    installShellCompletion --bash \
      --cmd rtcontrol build/lib/pyrocore/data/config/bash-completion
    for f in rtxmlrpc pyroadmin chtor lstor hashcheck mktor rtevent rtmv; do
      ln -s rtcontrol.bash $out/share/bash-completion/completions/$f.bash
    done

    # Install documentation
    mkdir -p $out/share/doc/pyroscope
    cp -rvt $out/share/doc/pyroscope \
      $src/docs/examples $src/src/scripts $src/src/pyrocore/data/config

    # Copy config files to out/lib
    mkdir -p $out/lib/pyroscope
    cp -r --no-preserve=mode -t $out/lib/pyroscope \
      $src/src/pyrocore/data/config/{color-schemes,rtorrent.d,templates,*.ini,*.py} \
      build/lib/pyrocore/data
    substitute ${./config.tpl.ini} $out/lib/pyroscope/config.ini \
      --subst-var-by pyroscope $out/lib/pyroscope
    substitute ${./rtorrent-pyro.rc} $out/lib/pyroscope/rtorrent-pyro.rc \
      --subst-var-by rtorrent_d $out/lib/pyroscope/rtorrent.d
  '';

  postFixup = ''
    # Pyrocore import for RT
    $out/bin/pyroadmin -q --create-import "$out/lib/pyroscope/rtorrent.d/*.rc"
  '';
}
