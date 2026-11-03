{ runCommand
, replaceVarsWith
, pyrocore
}:

let
  checkImports = dir: ''
    # check all required imports exist and are readable
    listImports () {
      if [[ $# -gt 0 ]]; then
        mapfile -t res < <(sed -n '/^import\s*=/{s/^import\s*=\s*"\?//; s/"\?\s*$// ;p}' "$@")
        printf '%s\n' "$@"
        listImports "''${res[@]}"
      fi
    }

    mapfile -t imports < <(listImports ${dir})

    for f in "''${imports[@]}"; do
      if [[ -r $f ]]; then
        echo "Imported: $f"
      else
        echo "error: cannot find imported file: $f" >&2
        exit 1
      fi
    done
  '';
in
{
  createRtorrentRC =
    { colorScheme ? "default-16"
    , colorSchemeImport ? "${pyrocore}/lib/pyroscope/color-schemes/${colorScheme}.rc"
    , extraConfig ? ""
    , mainConfigD ? ./rtorrent.d
    , extraReplacements ? { }
    }:
    let
      mainImport = pyrocore.createImport {
        src = mainConfigD;
        env = {
          inherit pyrocore;
          inherit (pyrocore) rtorrentPyroRC;
        } // extraReplacements;
      };
    in
    runCommand "rtorrent.rc" {
    } ''
      install -Dm0644 ${replaceVarsWith {
        src = ./main.rtorrent.rc;
        replacements = {
          inherit mainImport colorSchemeImport extraConfig;
        };

        postCheck = ''
          ${checkImports "$out"}
        '';
      }} $out
    '';
}
