final: prev:

let
  # TODO
  RT_HOME = "/home/sim/RT";
in

{
    rtorrent-configs = final.callPackage ./rtorrent-ps/rtorrent-configs.nix {
      inherit RT_HOME; # pyrocore;
    };
    rtorrent-ps = final.callPackage ./rtorrent-ps {
      inherit RT_HOME; # rtorrent pyrocore rtorrent-configs;
    };
    libtorrent = final.callPackage ./libtorrent {
      #inherit rtorrent-ps;
    };
    rtorrent = final.callPackage ./rtorrent {
      #inherit libtorrent rtorrent-ps;
    };
    pyrocore = final.callPackage ./pyrocore {
      inherit (final.python2Packages) buildPythonPackage setuptools six;
    };
}
