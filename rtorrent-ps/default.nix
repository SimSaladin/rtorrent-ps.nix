{ lib
, callPackage
, fetchFromGitHub
, rtorrentVersions
}@args:

let
  builder =
    { src
    , rtorrent
    , ...
    }@bargs:
    callPackage ./builder.nix (args // bargs);

in
lib.recurseIntoAttrs rec {
  rtorrentPSVersion = "1.1-71-gee296b1";

  rtorrent-ps_1_1-71-gee296b1 = builder {
    inherit rtorrentPSVersion;
    src = fetchFromGitHub {
      owner = "pyroscope";
      repo = "rtorrent-ps";
      rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
      hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
    };
    rtorrent = rtorrentVersions.latest;
  };

  latest = rtorrent-ps_1_1-71-gee296b1;
}
