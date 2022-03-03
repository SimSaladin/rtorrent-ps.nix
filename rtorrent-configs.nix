{ runCommand
, pyrocore
, RT_HOME
, RT_SOCKET ? "${RT_HOME}/.scgi_local"
}:

# - rtorrent.rc
# - rtorrent.d/*.rc
# - rtorrent.d/.import.rc
# - pyroscope/config.ini
# - pyroscope/color-schemes/

runCommand "rtorrent-configs" {
  inherit RT_HOME RT_SOCKET;
}
''
  export pyrocore=${pyrocore} pyroscope=${pyrocore}/share/pyroscope
  export RTORRENT_RC=$out/rtorrent.rc

  mkdir -p $out/{rtorrent.d,pyroscope}

  # rtorrent.d
  cp -r ${./rtorrent.d}/* $out/rtorrent.d
  # Generate rtorrent.d/.import.rc
  ${pyrocore}/bin/pyroadmin -q --create-import "$out/rtorrent.d/*.rc"

  # rtorrent.rc
  cp ${./rtorrent.rc} $out/rtorrent.rc

  # /pyroscope
  ln -s -t $out/pyroscope $pyroscope/*
  # Customize config.ini
  rm $out/pyroscope/config.ini
  substitute ${./config.ini} $out/pyroscope/config.ini \
    --subst-var RTORRENT_RC \
    --subst-var pyroscope

  for file in $out/*.rc $out/rtorrent.d/*.rc; do
    substituteInPlace "$file" \
      --subst-var RT_SOCKET \
      --subst-var-by confdir $out/rtorrent.d \
      --subst-var pyrocore \
      --subst-var pyroscope
  done
''
