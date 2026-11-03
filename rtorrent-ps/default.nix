{ self, lib ? self.lib }:

let
  builder = bargs: self.callPackage ./builder.nix bargs;

in
lib.makeExtensible (self': lib.recurseIntoAttrs {
  rtorrentPSVersion = "1.1-71-gee296b1";

  rtorrent-ps_1_1-71-gee296b1 = builder {
    inherit (self') rtorrentPSVersion;
    rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
    hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
    rtorrent = self.rtorrentVersions.latest;
  };

  latest = self'.rtorrent-ps_1_1-71-gee296b1;
})
