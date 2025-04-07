{ lib
, callPackage
, rtorrent-ps-src
, rtorrentPackages
}:

let

  rtorrentPSBuild = args0: let
    builder = import ./common.nix;
    args = {
      inherit rtorrent-ps-src;
      rtorrent = rtorrentPackages.${args0.rtorrentVersion};
    } // args0;
  in
    callPackage builder (lib.intersectAttrs (lib.functionArgs builder) args);

in
# by rtorrent version
lib.recurseIntoAttrs (lib.fix (self: {

  rtorrent-ps_0_96 = self."0.9.6";
  rtorrent-ps_0_97 = self."0.9.7";
  rtorrent-ps_0_98 = self."0.9.8";
  rtorrent-ps_master = self."0.9.8-20230416";

  latest = self.rtorrent-ps_master;
  stable = self.rtorrent-ps_0_96;

  "0.9.6" = rtorrentPSBuild { rtorrentVersion = "0.9.6"; };
  "0.9.7" = rtorrentPSBuild { rtorrentVersion = "0.9.7"; };
  "0.9.8" = rtorrentPSBuild { rtorrentVersion = "0.9.8"; };
  "0.9.8-20230416" = rtorrentPSBuild { rtorrentVersion = "0.9.8-20230416"; };
}))
