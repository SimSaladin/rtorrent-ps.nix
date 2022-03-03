{ RT_HOME ? null # XXX
}:

# NOTE:
# Variable PYRO_CONFIG_DIR=${rtorrent-configs}/pyroscope
# is baked into each executable's environment. It's needed to locate the scgi
# socket:
#
#   1. Read key "rtorrent_rc" from "config.ini" in $PYRO_CONFIG_DIR to locate
#      the main rtorrent configuration file.
#   2. Parse "network.scgi.open_local = <file>" from the rtorrent.rc file.
#      This must be a literal value which points to the socket file.
#
# The main config file is: ${rtorrent-configs}/rtorrent.rc

final: prev: {

  # NOTE: needs RT_HOME to bake the scgi socket into the configs
  rtorrent-configs = final.callPackage ./rtorrent-configs.nix {
    inherit RT_HOME;
  };

  # NOTE: uses RT_HOME to bake it into the start script
  rtorrent-ps = final.callPackage ./rtorrent-ps { };

  libtorrent = final.callPackage ./libtorrent { };

  rtorrent = final.callPackage ./rtorrent { };

  pyrocore = final.callPackage ./pyrocore {
    inherit (final.python2Packages) buildPythonPackage setuptools six;
  };
  ProxyTypes = final.callPackage ./pyrocore/ProxyTypes.nix { inherit (final.python2Packages) buildPythonPackage; };
  pyrobase = final.callPackage ./pyrocore/pyrobase.nix { inherit (final.python2Packages) buildPythonPackage six; };
}
