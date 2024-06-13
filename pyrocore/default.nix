{ callPackage
, fetchFromGitHub
, runCommand
, installShellFiles
, py2 # Must be sufficiently old sphinx
}:

let
  inherit (py2.pkgs) buildPythonPackage setuptools requests prompt-toolkit tempita six;

  pyrobase = callPackage ./pyrobase.nix { inherit buildPythonPackage six tempita; };

  ProxyTypes = callPackage ./ProxyTypes.nix { inherit buildPythonPackage; };

  pyrocore = buildPythonPackage {
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
      ./rtxmlrpc-history-file.patch
      # Should not be applied when prompt-toolkit is sufficiently old (lol)
      #./fix_prompt_toolkit_import.patch
    ];

    nativeBuildInputs = [
      installShellFiles
    ];

    propagatedBuildInputs = [
      ProxyTypes
      prompt-toolkit
      pyrobase
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
      cp -rt $out/share/doc/pyroscope \
        $src/docs/examples \
        $src/src/scripts \
        $src/src/pyrocore/data/config
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
      pyEnv = pyrocoreEnv;
      createImport = createPyroImportForDirectory;
    };
  };

  pyrocoreEnv = py2.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  createPyroImportForDirectory = { src, ... }@args:
    let
      dir = runCommand "imports.rtorrent.rc" args
      ''
        mkdir -p $out
        for f in $src/*.rc{,.include}; do
          o="$out/$(basename "$f")"
          substituteAll "$f" "$o"
          if found=$(grep -o '^[^#]*\(@[A-Za-z][A-Za-z0-9_]*@\)' "$o"); then
            echo "error: not substitutions were made in file $f: $found" >&2
            exit 1
          fi
        done
        ${pyrocore}/bin/pyroadmin -q --create-import "$out/*.rc"
      '';
    in
    "${dir}/.import.rc";

in
pyrocore
