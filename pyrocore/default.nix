{ lib
, runCommand
, pkgs2111
}:

let
  inherit (pkgs2111) python2; /* Must have sufficiently old sphinx */
in
rec {
  pyrobase = python2.pkgs.callPackage ./pyrobase.nix { };

  ProxyTypes = python2.pkgs.callPackage ./ProxyTypes.nix { };

  pyrocore = python2.pkgs.callPackage ./pyrocore.nix {
    inherit pyrobase ProxyTypes;
    passthru.pyEnv = pyrocore-env;
    passthru.createImport = pyrocore-create-imports;
  };

  pyrocore-env = python2.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  # NOTE: args should have non-null src
  pyrocore-create-imports = args:
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
}
