{ pkgs2111
, runCommand
, fetchFromGitHub
, makeWrapperArgs ? [ ]
, passthru ? { }
}:

let
  inherit (pkgs2111) python2; /* Must have sufficiently old sphinx */

  pyrobase = python2.pkgs.callPackage ./pyrobase.nix { };

  ProxyTypes = python2.pkgs.callPackage ./ProxyTypes.nix { };

  pyrocore = python2.pkgs.buildPythonPackage {
    pname = "pyrocore";
    version = "0.6.1";

    src = fetchFromGitHub {
      owner = "pyroscope";
      repo = "pyrocore";
      rev = "9d8737d96ccb75abcc1af313cde7b8278b9d83bb";
      hash = "sha256-uxzLBgk9YRMQMkxgjB+prmS4EcajxQ7sNfPEPR9p6Uw=";
    };

    inherit makeWrapperArgs;

    patches = [
      ./patches/read_config_values_from_env.patch
      ./patches/rtxmlrpc-history-file.patch
      # Should not be applied when prompt-toolkit is sufficiently old (lol)
      #./patches/fix_prompt_toolkit_import.patch
    ];

    nativeBuildInputs = [ pkgs2111.installShellFiles ];

    propagatedBuildInputs = with python2.pkgs; [
      setuptools
      prompt-toolkit
      requests
      tempita
    ] ++ [ ProxyTypes pyrobase ];

    doCheck = false;

    postInstall = ''
      mkdir -p $out/lib/pyroscope

      # Default pyroscope configuration
      cp -r --no-preserve=mode -t $out/lib/pyroscope \
        $src/src/pyrocore/data/config/{color-schemes,rtorrent.d,templates,*.ini,*.py}

      cp -r --no-preserve=mode -t $out/lib/pyroscope \
        build/lib/pyrocore/data

      # Default PyroScope configuration file (config.ini)
      substitute ${../rtorrent-config/config.tpl.ini} $out/lib/pyroscope/config.ini \
        --subst-var-by pyroscope $out/lib/pyroscope

      substitute ${../rtorrent-config/rtorrent-pyro.rc} $out/lib/pyroscope/rtorrent-pyro.rc \
        --subst-var-by rtorrent_d $out/lib/pyroscope/rtorrent.d

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
    '';

    postFixup = ''
      # Pyrocore import for RT
      $out/bin/pyroadmin -q --create-import "$out/lib/pyroscope/rtorrent.d/*.rc"
    '';

    passthru = passthru // {

      inherit createImport;

      # Note: unlike the executables in pyrocore, here the python env (NIX_*
      # variables) is setup correctly so that if setting PYTHONPATH in environment
      # does not break the executables...
      pyEnv = python2.buildEnv.override {
        extraLibs = [ pyrocore ];
        ignoreCollisions = true;
      };
    };
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
        ${pyrocore}/bin/pyroadmin -q --create-import "$out/*.rc"
      '';
    in
    "${dir}/.import.rc";
in
  pyrocore
