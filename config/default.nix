{ runCommand
, pyrocore
}:
let
  basedir = "/tmp/myrt"; # /media/moore/rtorrent
in
runCommand "rtorrent.d" {} ''
  mkdir -p $out/rtorrent.d

  # rtorrent.rc
  cp ${./rtorrent.rc} $out/rtorrent.rc

  # rtorrent.d
  cp -r ${./rtorrent.d}/* $out/rtorrent.d

  # rtorrent.d/.import.rc
  ${pyrocore}/bin/pyroadmin -q --create-import "$out/rtorrent.d/*.rc"

  for file in $out/*.rc $out/*/*.rc; do
    substituteInPlace "$file" \
      --subst-var-by pyroscope   ${pyrocore} \
      --subst-var-by confdir     $out/rtorrent.d \
      --subst-var-by scgi_socket ${basedir}/.scgi_local
  done

  # pyroscope
  mkdir -p $out/pyroscope
  substitute ${./config.ini} $out/pyroscope/config.ini \
    --subst-var-by pyroscope ${pyrocore}/share/pyroscope \
    --subst-var-by rtorrent_rc $out/rtorrent.rc
'' // { RT_HOME = basedir; }
