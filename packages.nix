{ lib, pkgs }:

lib.recurseIntoAttrs (lib.makeScope pkgs.newScope (self: {

  lib = lib.extend (import ./functions.nix);

  rtorrent-ps = import ./rtorrent-ps { inherit lib pkgs self; };
  rtorrentVersions = import ./rtorrent { inherit pkgs self; };
  libtorrentVersions = import ./libtorrent { inherit pkgs self; };

  pyrocore = import ./pyrocore { inherit pkgs; };

  rtorrent-config = self.callPackage ./rtorrent-config { };
  rtorrent-magnet = self.callPackage ./rtorrent-magnet { };
}))
