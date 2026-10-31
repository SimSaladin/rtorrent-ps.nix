{ lib, pkgs, self }:

let
  builder = bargs: self.callPackage ./builder.nix bargs;

in
lib.recurseIntoAttrs rec {
  rtorrentPSVersion = "1.1-71-gee296b1";

  rtorrent-ps_1_1-71-gee296b1 = builder {
    inherit rtorrentPSVersion;
    src = pkgs.fetchFromGitHub {
      owner = "pyroscope";
      repo = "rtorrent-ps";
      rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
      hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
    };
    rtorrent = self.rtorrentVersions.latest;
  };

  latest = rtorrent-ps_1_1-71-gee296b1;
}
