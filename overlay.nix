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
  inherit (final.callPackage ./libtorrent { })
    mkLibtorrent
    libtorrent_0_13_6
    libtorrent_0_13_7
    ;

  libtorrent = final.libtorrent_0_13_6;

  inherit (final.callPackage ./rtorrent { })
    mkRtorrent
    rtorrent_0_9_6
    rtorrent_0_9_7
    ;

  rtorrent = final.rtorrent_0_9_6;

  rtDebug = final.enableDebugging (final.rtorrent_0_9_7.override { dontStrip = true; });

  rtorrent-ps = final.callPackage ./rtorrent-ps { };
  rtorrent-ps_0_9_7 = final.rtorrent-ps.override {
    rtorrent = final.rtorrent_0_9_7;
    rtorrent-configs = final.rtorrent-configs_0_9_7;
  };

  rtorrent-configs = final.callPackage ./rtorrent-configs.nix { };
  rtorrent-configs_0_9_7 = final.rtorrent-configs.override {
    rtorrent = final.rtorrent_0_9_7;
  };

  pyrocore = final.callPackage ./pyrocore { inherit (final.python2Packages) buildPythonPackage setuptools six; };

  pyrobase = final.callPackage ./pyrobase.nix { inherit (final.python2Packages) buildPythonPackage six; };

  ProxyTypes = final.callPackage ./ProxyTypes.nix { inherit (final.python2Packages) buildPythonPackage; };
}
