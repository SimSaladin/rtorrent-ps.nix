{ lib
, stdenv
, makeWrapper
, buildPythonPackage
, python2
, setuptools
, prompt-toolkit
, requests
, tempita
, ProxyTypes
, pyrobase
, installShellFiles
, fetchFromGitHub
, runCommand
, writeShellApplication
, makeWrapperArgs ? [ ]
, passthru ? { }
}:

lib.fix (finalPackage:

  buildPythonPackage {
    pname = "pyrocore";
    version = "0.6.1";

    src = fetchFromGitHub {
      owner = "pyroscope";
      repo = "pyrocore";
      rev = "9d8737d96ccb75abcc1af313cde7b8278b9d83bb";
      hash = "sha256-uxzLBgk9YRMQMkxgjB+prmS4EcajxQ7sNfPEPR9p6Uw=";
    };

    makeWrapperArgs = [
      "--set-default PYRO_CONFIG_DIR $out/lib/pyroscope"
      "--prefix PATH : $out/bin"
    ] ++ makeWrapperArgs;

    patches = [
      ./patches/read_config_values_from_env.patch
      ./patches/rtxmlrpc-history-file.patch
      ./patches/fake-argument-fix.patch
      # Should not be applied when prompt-toolkit is sufficiently old (lol)
      #./patches/fix_prompt_toolkit_import.patch
    ];

    nativeBuildInputs = [
      installShellFiles
      makeWrapper
    ];

    propagatedBuildInputs = [
      setuptools
      prompt-toolkit
      requests
      tempita
      ProxyTypes
      pyrobase
    ];

    doCheck = false;

    preBuild = ''
      nixInfoLog(){
        echo "nix info: $*" >&2
      }
    '';

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
        $src/src/pyrocore/data/config/{color-schemes,templates,*.ini,*.py} \
        build/lib/pyrocore/data \
        ${./.}/rtorrent.d
      substitute ${./config.tpl.ini} $out/lib/pyroscope/config.ini \
        --subst-var-by pyroscope $out/lib/pyroscope
      substitute ${./rtorrent-pyro.rc} $out/lib/pyroscope/rtorrent-pyro.rc \
        --subst-var-by pyroscope $out/lib/pyroscope
    '';

    postFixup = ''
      # Pyrocore import for RT
      $out/bin/pyroadmin -q --create-import "$out/lib/pyroscope/rtorrent.d/*.rc"

      # Since 0.16.27
      for f in $out/lib/pyroscope/rtorrent.d/*.rc; do
        sed -i -e 's/schedule2/schedule/g' "$f"
      done
    '';

    passthru = rec {

      # Note: unlike the executables in pyrocore, here the python env (NIX_*
      # variables) is setup correctly so that if setting PYTHONPATH in environment
      # does not break the executables...
      pyEnv = python2.buildEnv.override {
        extraLibs = [ finalPackage ];
        ignoreCollisions = true;
      };

      rtorrentConfigString =
        let
          imports = lib.splitString "\n" (lib.fileContents "${finalPackage}/lib/pyroscope/rtorrent.d/.import.rc");
        in
        lib.concatMapStringsSep "\n" (x: ''
          # print = "${lib.escape ["\""] x}"
          ${x}
        '') imports;

      rtorrentPyroRC = "${finalPackage}/lib/pyroscope/rtorrent-pyro.rc";

      createImport = { src, env ? { } }:
        "${runCommand "create-import" { inherit src env; } ''${lib.getExe create-import} $src $out''}/.import.rc";

      # Writes a $out/.import.rc which can be imported.
      #
      # The pyrocore import should be imported by some input file like so:
      #
      #   import = @rtorrentPyroImportRC@
      #
      create-import = writeShellApplication {
        name = "pyrocore-create-import";
        runtimeInputs = [ finalPackage ];
        text = ''
          export SRC=''${1?Source directory missing}
          export DEST=''${2?Destination directory missing}
          mkdir -p "$DEST"
          ({
            # shellcheck disable=SC1091
            source ${stdenv}/setup

            for inF in "$SRC"/*.rc{,.include}; do
              outF=$DEST/$(basename "$inF")
              substituteAll "$inF" "$outF"
              if found=$(grep -o '\(@[A-Za-z][A-Za-z0-9_]*@\)' "$outF"); then
                echo "error: placeholder '$found' was not substituted (file: '$inF')! Maybe you should define it?" >&2
                exit 1
              fi
              # Since 0.16.27...
              sed -i -e 's/schedule2/schedule/g' "$outF"
            done
          })
          pyroadmin -q --create-import "$DEST/*.rc"
        '';
      };
    } // passthru;
  }
)
