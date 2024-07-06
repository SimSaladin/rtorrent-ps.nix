{ callPackage
, rtorrent-magnet
, rtorrent-ps-src
, pyrocore
, rtorrentVersions
}:

let
  common = args:
    callPackage ./common.nix { } ({ inherit rtorrent-ps-src rtorrent-magnet pyrocore; } // args);

  # by rtorrent version
  self = {
    latest = self.rtorrent-ps_master;
    stable = self.rtorrent-ps_0_96;

    rtorrent-ps_0_96 = common { rtorrent = rtorrentVersions.rtorrent_0_96; };
    rtorrent-ps_0_97 = common { rtorrent = rtorrentVersions.rtorrent_0_97; };
    rtorrent-ps_0_98 = common { rtorrent = rtorrentVersions.rtorrent_0_98; };
    rtorrent-ps_master = common { rtorrent = rtorrentVersions.rtorrent_master; };

    recurseForDerivations = true;
  };

in
self
