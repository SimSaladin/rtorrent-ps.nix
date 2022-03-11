{ rtorrentLib
, substituteAll
, runCommand
, pyrocore
}:
rec {
  rtConfigs = rtorrentLib.createImport ./rtorrent.d {
    pyroscope = pyroConfigs;
  };

  rtorrentRc = substituteAll {
    src = ./rtorrent.rc;
    pyroscope = pyroConfigs;
    inherit rtConfigs;
  };

  pyroConfigs = runCommand "pyroConfigs" { } ''
    mkdir -p $out

    cp -r --no-preserve=mode -t $out ${pyrocore.src}/src/pyrocore/data/config/{color-schemes,rtorrent.d,templates,*.ini,*.py}
    ${pyrocore}/bin/pyroadmin -q --create-import $out/rtorrent.d/*.rc

    substitute ${./config.ini} $out/config.ini \
      --subst-var-by pyroscope $out
    substitute ${../pyrocore/rtorrent-pyro.rc} $out/rtorrent-pyro.rc \
      --subst-var-by rtorrent_d $out/rtorrent.d
  '';
}
