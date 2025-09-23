{ lib, pkgs, sources }:

let
  mkPackages = self: ps:
    lib.makeScope self.newScope (self: {
      libtorrentPackages = self.callPackage ./libtorrent { ps = ps; };
      rtorrentPackages = self.callPackage ./rtorrent { ps = ps; };
      rtorrentPSPackages = self.callPackage ./rtorrent-ps { ps = ps; };
    });
in
lib.recurseIntoAttrs (lib.makeScope pkgs.newScope (self: {

  inherit sources;

  pyrocore = self.callPackage ./pyrocore { };
  rtorrent-magnet = self.callPackage ./rtorrent-magnet { };
  rtorrent-config = self.callPackage ./rtorrent-config { };

  rtorrent-ps = self.rtorrentPSPackages.${lib.versionToName "latest/PS${sources.defaults.rtorrent-ps}"};
}
//
lib.fold lib.recursiveUpdate { } (lib.map (mkPackages self) sources.rtorrent-ps)))
