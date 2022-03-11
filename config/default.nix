{ runCommand
, substituteAll
, rtorrent
, pyrocore
  # TODO somehow get rid of this here
, rtSocket ? null # "${RT_HOME}/.scgi_local"
}:

rec {
  pyroscope = "${pyrocore}/share/pyroscope";

  rtConfigs = runCommand "rtorrent.d" {
    buildInputs = [ pyrocore ];
    inherit pyroscope;
  } ''
    mkdir -p $out
    for file in ${./rtorrent.d}/*; do
      substituteAll "$file" "$out/$(basename "$file")"
    done
    pyroadmin -q --create-import "$out/*.rc"
  '';

  rtorrentRc = substituteAll {
    src = ./rtorrent.rc;
    inherit pyrocore pyroscope rtConfigs rtSocket;
  };

  pyroConfigIni = substituteAll {
    src = ./config.ini;
    inherit pyroscope rtorrentRc;
  };

  pyroConfigs = runCommand "pyroConfigs" { } ''
    mkdir -p $out
    ln -s ${pyroscope}/* $out/
    ln -snf ${pyroConfigIni} $out/config.ini
  '';

  # Note: to use this script, set environment variables:
  #   RT_HOME RT_SOCKET RT_INITRC
  startScript = substituteAll {
    src = ./start.sh;
    rtorrent = "${rtorrent}/bin/rtorrent";
    postInstall = "chmod 0755 $out";
  };
}
