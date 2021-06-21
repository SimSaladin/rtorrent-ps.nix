{ nixpkgs ? import <nixpkgs> {} }:

with nixpkgs;

let
  packages = rec {
    rtorrent-ps = callPackage ./rtorrent-ps { inherit rtorrent rtorrent-configs pyrocore; };
    libtorrent = callPackage ./libtorrent { inherit rtorrent-ps; };
    rtorrent = callPackage ./rtorrent { inherit libtorrent rtorrent-ps; };
    pyrocore = callPackage ./pyrocore { inherit (python2Packages) buildPythonPackage setuptools six; };
    rtorrent-configs = callPackage ./config { inherit pyrocore; };
  };
in {
  inherit (packages) rtorrent-ps;
}
