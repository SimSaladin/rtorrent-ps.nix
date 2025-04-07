{ lib
, callPackage
, rtorrent-ps-src
, rtorrentPackages
, pyrocore
, rtorrent-magnet
}:

let
  common = args:
  let
    wrapper = callPackage ./common.nix { };
    args' = { inherit rtorrent-ps-src rtorrent-magnet pyrocore; } // args;
  in
    lib.makeOverridable wrapper args';

in
# by rtorrent version
lib.recurseIntoAttrs rec {
  latest = rtorrent-ps_master;
  stable = rtorrent-ps_0_96;

  rtorrent-ps_0_96 = common { rtorrent = rtorrentPackages.rtorrent_0_96; };
  rtorrent-ps_0_97 = common { rtorrent = rtorrentPackages.rtorrent_0_97; };
  rtorrent-ps_0_98 = common { rtorrent = rtorrentPackages.rtorrent_0_98; };
  rtorrent-ps_master = common { rtorrent = rtorrentPackages.rtorrent_master; };
}
