{ lib
, callPackage
, ps
, rtorrentPackages
}:

let
  rtorrentPSBuild = args0:
    callPackage ./common.nix ({ inherit ps; } // removeAttrs args0 [ "rtorrentVersion" ]);

in
# by rtorrent version
lib.recurseIntoAttrs (lib.mapSuffix "PS${ps.version}" (lib.fix (self:
lib.mapAttrs' (_: rtorrent: {
  name = rtorrent.rtorrentVersion;
  value = rtorrentPSBuild { inherit rtorrent; rtorrentVersion = rtorrent.rtorrentVersion; };
}) (lib.filterAttrs (_: x: lib.isDerivation x) rtorrentPackages)

// {
  latest = self."0.16.0-next";
})))
