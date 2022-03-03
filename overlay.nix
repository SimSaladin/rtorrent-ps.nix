{ ... }:

# NOTE:
# Variable PYRO_CONFIG_DIR=${rtorrent-configs}/pyroscope
# is baked into each executable's environment. It's needed to locate the scgi
# socket:
#
#   1. Read key "rtorrent_rc" from "config.ini" in $PYRO_CONFIG_DIR to locate
#      the main rtorrent configuration file.
#   2. Parse "network.scgi.open_local = <file>" from the rtorrent.rc file.
#      This must be a literal value which points to the socket file.

final: prev: {
  rtorrent-ps = final.callPackage ./rtorrent-ps { };
  rtorrent-configs = final.callPackage ./rtorrent-configs.nix { };
  libtorrent = final.callPackage ./libtorrent { };
  rtorrent = final.callPackage ./rtorrent { };
  pyrocore = final.callPackage ./pyrocore { inherit (final.python2Packages) buildPythonPackage setuptools six; };
  ProxyTypes = final.callPackage ./pyrocore/ProxyTypes.nix { inherit (final.python2Packages) buildPythonPackage; };
  pyrobase = final.callPackage ./pyrocore/pyrobase.nix { inherit (final.python2Packages) buildPythonPackage six; };
}
