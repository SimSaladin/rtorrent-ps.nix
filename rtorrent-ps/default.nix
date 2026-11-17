{ self
, lib ? self.lib
, rtorrentVersions ? self.rtorrentVersions
,
}:

let
  rtorrentPSVersion = "1.1-71-gee296b1";
in

lib.makeExtensible (
  self':
  lib.recurseIntoAttrs {

    latest = self'.rtorrent-ps_1_1-71-gee296b1;

    rtorrent-ps_1_1-71-gee296b1 = self.callPackage ./package.nix {
      rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
      hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
      rtorrent = rtorrentVersions.latest;
      inherit rtorrentPSVersion;
    };

    inherit rtorrentPSVersion;
  }
)
