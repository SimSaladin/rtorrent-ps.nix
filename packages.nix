{ lib, pkgs }:

lib.recurseIntoAttrs (lib.makeScope pkgs.newScope (self: {

  lib = lib.extend (import ./functions.nix);

  pyrocore = self.callPackage ./pyrocore { };

  rtorrent-magnet = self.callPackage ./rtorrent-magnet { };

  rtorrent-config = self.callPackage ./rtorrent-config { };

  libtorrentVersions = lib.callPackagesWith (pkgs // self) ./libtorrent { };

  rtorrentVersions = lib.callPackagesWith (pkgs // self) ./rtorrent { };

  rtorrent-ps = lib.callPackagesWith (pkgs // self) ./rtorrent-ps { };
}))
