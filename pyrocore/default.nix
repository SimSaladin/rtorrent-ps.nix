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

  pyrocore = python2.pkgs.callPackage ./pyrocore.nix {
    inherit pyrobase ProxyTypes;
    inherit fetchFromGitHub;
    inherit makeWrapperArgs;
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
