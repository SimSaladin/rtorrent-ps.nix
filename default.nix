{ nixpkgs ? import <nixpkgs> {}
, RT_HOME ? "${builtins.getEnv "HOME"}/.rtorrent"
}:

with nixpkgs;

let
  packages = rec {
    rtorrent-ps = callPackage ./rtorrent-ps { inherit rtorrent pyrocore RT_HOME; };
    libtorrent = callPackage ./libtorrent { inherit rtorrent-ps; };
    rtorrent = callPackage ./rtorrent { inherit libtorrent rtorrent-ps; };
    pyrocore = callPackage ./pyrocore { inherit (python2Packages) buildPythonPackage setuptools six; };
  };
in {
  inherit (packages) rtorrent-ps;
}
