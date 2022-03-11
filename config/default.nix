{ rtorrentLib
, substituteAll
, runCommand
, pyrocore
}:
let pyroscope = "${pyrocore}/share/pyroscope";
in
rec {
  rtConfigs = rtorrentLib.createImport ./rtorrent.d { inherit pyroscope; };

  rtorrentRc = substituteAll {
    src = ./rtorrent.rc;
    inherit pyrocore pyroscope rtConfigs;
  };

  pyroConfigIni = substituteAll {
    src = ./config.ini;
    inherit pyroscope;
  };

  pyroConfigs = runCommand "pyroConfigs" { } ''
    mkdir -p $out
    ln -s ${pyroscope}/* $out/
    ln -snf ${pyroConfigIni} $out/config.ini
  '';
}
