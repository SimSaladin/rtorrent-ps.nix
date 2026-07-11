{ lib
, stdenv
, installShellFiles
, writeShellApplication
, makeWrapper
, coreutils
, lsof
, lndir
, pyrocore
, rtorrent-magnet
, rtorrent-config

, src
, version
, rtorrent
, writeInitRc
, writeStartScript
, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, PYRO_CONFIG_DIR ? "${pyrocore}/lib/pyroscope"
, colorScheme ? "solarized-blue"
}@args:

let
  initRc = writeInitRc { inherit colorScheme; };
in
import ./unwrapped.nix (args // {
  version = "${version}+${rtorrent.version}";

  inherit initRc;

  startScript = { pname, ... }:
    writeStartScript {
      inherit pname;
      inherit initRc;
      inherit rtorrent RT_HOME RT_SOCKET PYRO_CONFIG_DIR;
    };
})
