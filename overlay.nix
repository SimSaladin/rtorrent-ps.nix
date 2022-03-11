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
  #rtDebug = final.enableDebugging (final.rtorrent_0_9_7.override { withDebug = true; });

  rtorrent-ps = final.callPackage ./rtorrent-ps { };
  rtorrent-ps_0_9_7 = final.rtorrent-ps.override {
    rtorrent = final.rtorrent_0_9_7;
  };

  rtorrent-configs = final.callPackage ./config { };

  pyrocore = final.callPackage ./pyrocore {
    inherit (final.python2Packages) buildPythonPackage setuptools six;
    prompt_toolkit = final.prompt_toolkit_2;
  };

  pyrobase = final.callPackage ./pyrobase.nix {
    inherit (final.python2Packages) buildPythonPackage six;
  };

  ProxyTypes = final.callPackage ./ProxyTypes.nix { inherit (final.python2Packages) buildPythonPackage; };

  prompt_toolkit_2 = final.callPackage ./prompt_toolkit_2.nix { inherit (final.python2Packages) buildPythonPackage six wcwidth; };

  rtorrentLib.createImport = src: attrs: final.runCommand "create-import" attrs
  ''
    mkdir -p $out
    for f in ${src}/*; do
      substituteAll "$f" $out/"$(basename "$f")"
    done
    ${final.pyrocore}/bin/pyroadmin -q --create-import "$out/*.rc"
  '';
}
