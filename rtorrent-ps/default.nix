{ lib
, callPackage
, ps
, rtorrentPackages
}:

let
  rtorrentPSBuild = args0: let
    builder = import ./common.nix;
    args = {
      inherit ps;
      rtorrent = rtorrentPackages.${lib.versionToName "${args0.rtorrentVersion}/PS${ps.version}"};
    } // removeAttrs args0 [ "rtorrentVersion" ];
  in
    callPackage builder args;

in
# by rtorrent version
lib.recurseIntoAttrs (lib.mapSuffix "PS${ps.version}" (lib.fix (self: {

  "0.9.6" = rtorrentPSBuild { rtorrentVersion = "0.9.6"; };
  "0.9.7" = rtorrentPSBuild { rtorrentVersion = "0.9.7"; };
  "0.9.8" = rtorrentPSBuild { rtorrentVersion = "0.9.8"; };

  "0.9.8-20230416" = rtorrentPSBuild {
    rtorrentVersion = "0.9.8-20230416";
  };

  "0.16.0" = rtorrentPSBuild {
    rtorrentVersion = "0.16.0-677f8f4";
  };

  latest = self."0.16.0";
})))
