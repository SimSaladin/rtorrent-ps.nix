{ runCommand
, replaceVarsWith
, pyrocore
}:

{
  createRtorrentRC =
    { colorScheme ? "default-16"
    , colorSchemeRC ? "${pyrocore}/lib/pyroscope/color-schemes/${colorScheme}.rc"
    , extraConfig ? ""
    , mainConfigD ? ./rtorrent.d
    , mainConfigDirImportRC ? pyrocore.createImport { src = mainConfigD; }
    , extraReplacements ? { }
    }:
    runCommand "rtorrent-cfg" { } ''
      install -Dm0644 ${replaceVarsWith rec {
        src = ./main.rtorrent.rc;
        replacements = {
          inherit
            colorSchemeRC
            extraConfig
            mainConfigDirImportRC
            ;
        } // extraReplacements;

        postCheck = ''
          if [[ ! -e ${replacements.colorSchemeRC} ]]; then
            echo "error: importable file $colorSchemeRC was not found!" >&2
            exit 1
          fi

          # check all required imports exist and are readable
          listImports () {
            if [[ $# -gt 0 ]]; then
              mapfile -t res < <(sed -n '/^import\s*=/{s/^import\s*=\s*"\?//; s/"\?\s*$// ;p}' "$@")
              printf '%s\n' "$@"
              listImports "''${res[@]}"
            fi
          }

          mapfile -t imports < <(listImports $out)

          for f in "''${imports[@]}"; do
            if [[ -r $f ]]; then
              echo "Imported: $f"
            else
              echo "error: cannot find imported file: $f" >&2
              exit 1
            fi
          done
        '';
      }} $out/rtorrent.rc
    '';
}
