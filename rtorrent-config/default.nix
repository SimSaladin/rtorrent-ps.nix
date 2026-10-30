{ runCommand
, replaceVarsWith
, pyrocore
}:

rec {
  rtorrentPyroImportRC = "${pyrocore}/lib/pyroscope/rtorrent-pyro.rc";

  mainConfigDirImportRC = pyrocore.createImport {
    src = ./rtorrent.d;
    inherit rtorrentPyroImportRC;
  };

  createRtorrentRC =
    { colorScheme ? "default-16"
    , colorSchemeRC ? "${pyrocore}/lib/pyroscope/color-schemes/${colorScheme}.rc"
    , extraConfig ? ""
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
        };
        postCheck = ''
          if [[ ! -e ${replacements.colorSchemeRC} ]]; then
            echo "error: importable file $colorSchemeRC was not found!" >&2
            exit 1
          fi
        '';
      }} $out/rtorrent.rc
    '';
}
