{ lib, pkgs, pkgs2111 ? pkgs.pkgs2111 }:

let
  inherit (pkgs2111) python2; /* Must have sufficiently old sphinx */
in

lib.recurseIntoAttrs (lib.makeScope pkgs.newScope (self: {

  lib = lib.extend (import ./functions.nix);

  # callPackage so that missing python2 pkgs are taken from old pkgset,
  # while everything else is from the default pkgset.
  callOldPythonPackage = lib.callPackageWith (self // pkgs // python2.pkgs // {
    inherit python2; });

  pyrobase = self.callOldPythonPackage ./pyrocore/pyrobase.nix { };

  ProxyTypes = self.callOldPythonPackage ./pyrocore/ProxyTypes.nix { };

  pyrocore = self.callOldPythonPackage ./pyrocore/pyrocore.nix { };

  rtorrent-ps = import ./rtorrent-ps { inherit self; };
  rtorrentVersions = import ./rtorrent { inherit pkgs self; };
  libtorrentVersions = import ./libtorrent { inherit pkgs self; };

  rtorrent-config = self.callPackage ./rtorrent-config { };
  rtorrent-magnet = self.callPackage ./rtorrent-magnet { };
}))
