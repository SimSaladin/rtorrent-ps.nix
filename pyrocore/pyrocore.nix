{ lib
, fetchFromGitHub
, installShellFiles
, runCommand
, python
, buildPythonPackage
, pyrobase # python dep
, ProxyTypes # python dep
, prompt-toolkit # python dep
, requests # python dep
, setuptools # python dep
, tempita # python dep
}:

let
  pyrocore = buildPythonPackage {
    pname = "pyrocore";
    version = "0.6.1";

    src = fetchFromGitHub {
      owner = "pyroscope";
      repo = "pyrocore";
      rev = "9d8737d96ccb75abcc1af313cde7b8278b9d83bb";
      hash = "sha256-uxzLBgk9YRMQMkxgjB+prmS4EcajxQ7sNfPEPR9p6Uw=";
    };

    patches = [
      ./read_config_values_from_env.patch
      ./rtxmlrpc-history-file.patch
      # Should not be applied when prompt-toolkit is sufficiently old (lol)
      #./fix_prompt_toolkit_import.patch
    ];

    nativeBuildInputs = [ installShellFiles ];

    propagatedBuildInputs = [
      pyrobase
      ProxyTypes
      prompt-toolkit
      requests
      setuptools
      tempita
    ];

    doCheck = false;

    postInstall = ''
      # Install shell completion
      installShellCompletion --bash --cmd rtcontrol $src/src/pyrocore/data/config/bash-completion
      for f in rtxmlrpc pyroadmin chtor lstor hashcheck mktor rtevent rtmv; do
        ln -s rtcontrol.bash $out/share/bash-completion/completions/$f.bash
      done

      # Install documentation
      mkdir -p $out/share/doc/pyroscope
      cp -rvt $out/share/doc/pyroscope \
        $src/docs/examples $src/src/scripts $src/src/pyrocore/data/config
    '';

    postFixup = ''
      mkdir -p $out/lib/pyroscope

      # Default pyroscope configuration
      cp -r --no-preserve=mode -t $out/lib/pyroscope \
        $src/src/pyrocore/data/config/{color-schemes,rtorrent.d,templates,*.ini,*.py}

      # Pyrocore import for RT
      $out/bin/pyroadmin -q --create-import "$out/lib/pyroscope/rtorrent.d/*.rc"
      substitute ${./rtorrent-pyro.rc} $out/lib/pyroscope/rtorrent-pyro.rc \
        --subst-var-by rtorrent_d $out/lib/pyroscope/rtorrent.d

      # Default PyroScope configuration file (config.ini)
      substitute ${./config.tpl.ini} $out/lib/pyroscope/config.ini \
        --subst-var-by pyroscope $out/lib/pyroscope
    '';

    passthru = {
      inherit pyEnv createImport;
    };
  };

  pyEnv = python.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  # NOTE: args should have non-null src
  createImport = args:
    let
      dir = runCommand "pyrocore-create-imports" args ''
        mkdir -p $out

        for infile in $src/*.rc{,.include}; do
          outfile=$out/$(basename "$infile")
          substituteAll "$infile" "$outfile"
          if found=$(grep -o '^[^#]*\(@[A-Za-z][A-Za-z0-9_]*@\)' "$outfile"); then
            echo "error: placeholder '$found' was not substituted in file '$infile' (value not found)." >&2
            exit 1
          fi
        done
        ${lib.getExe' pyrocore "pyroadmin"} -q --create-import "$out/*.rc"
      '';
    in
    "${dir}/.import.rc";

in
pyrocore
