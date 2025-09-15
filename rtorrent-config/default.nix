{ runCommand
, replaceVarsWith
, pyrocore
}:

{
  createRtorrentRC =
    { colorScheme ? "default-16"
    , extraConfig ? ""
    }:
    runCommand "rtorrent-cfg" { } ''
      install -Dm0644 ${replaceVarsWith rec {
        src = ./main.rtorrent.rc;
        replacements = {
          colorSchemeRC = "${pyrocore}/lib/pyroscope/color-schemes/${colorScheme}.rc";
          mainConfigDirImportRC = pyrocore.createImport {
            src = ./rtorrent.d;
            rtorrentPyroImportRC = "${pyrocore}/lib/pyroscope/rtorrent-pyro.rc";
          };
          inherit extraConfig;
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
