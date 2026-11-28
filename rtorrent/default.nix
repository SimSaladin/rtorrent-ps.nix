{ lib ? self.lib
, self
, pkgs
, pkgsGeneric ? pkgs.pkgsGeneric
, lua5_4 ? pkgs.lua5_4
, libtorrentVersions ? self.libtorrentVersions
, rtorrentPSVersion ? self.rtorrent-ps.rtorrentPSVersion
}:

lib.makeExtensible (
  self':
  lib.recurseIntoAttrs {
    latest = self'.rtorrent_0_16_28;
    debug = self'.latest.override {
      enableDebug = true;
    };

    rtorrent_0_16_28 = self.callPackage ./package.nix {
      version = "0.16.28";
      rev = "d37467a0c5d52e3d1e3dfb917c6946aa7753846b";
      hash = "sha256-UNuXN6QAKq87rJGwn9sx6PIhUaxavecVD2Q1OoFdWY4=";
      owner = "SimSaladin";
      libtorrent = libtorrentVersions.libtorrent_0_16_28;
      enableSystemd = true;
      withAutoreconfHook = true;
      withLua = true;
      lua = lua5_4;
      inherit (pkgsGeneric) stdenv;
      inherit rtorrentPSVersion;
    };

    rtorrent_0_16_27 = self.callPackage ./package.nix {
      version = "0.16.27";
      rev = "5444fad5fdd33018d4f8e3e06df2d3805f765ee0";
      hash = "sha256-fyI9K9BDlh1O16DWKggyXBSpfqUc2D3o9XBcajOYyqc=";
      owner = "SimSaladin";
      libtorrent = libtorrentVersions.libtorrent_0_16_27;
      enableSystemd = true;
      withAutoreconfHook = true;
      withLua = true;
      lua = lua5_4;
      inherit (pkgsGeneric) stdenv;
      inherit rtorrentPSVersion;
    };

    ## has ipv6 support and other fixes
    ## In particular: https://github.com/rakshasa/rtorrent/pull/1169
    #rtorrent_0_9_8-20230416 = builder {
    #  version = "0.9.8-20230416";
    #  rev = "1da0e3476dcabbf74b2e836d6b4c37b4d96bde09"; # Mar 16, 2023
    #  hash = "sha256-OXOZSMuNAU+VGwNyyfzcmkTRjDJq9HsKUNxZDYpSvFQ=";
    #  libtorrentVersion = "0.13.8-20230416";
    #  patches = [
    #    ./patches/ps-close_lowdisk_normal_all.patch
    #    ./patches/ps-dl-ui-find_0.9.8.patch
    #    "${ps}/patches/ps-import.return_all.patch"
    #    "${ps}/patches/ps-info-pane-is-default_all.patch"
    #    "${ps}/patches/ps-info-pane-xb-sizes_all.patch"
    #    ./patches/ps-issue-515_all.patch
    #    "${ps}/patches/ps-item-stats-human-sizes_all.patch"
    #    "${ps}/patches/ps-log_messages_all.patch"
    #    "${ps}/patches/ps-object_std-map-serialization_all.patch"
    #    "${ps}/patches/ps-silent-catch_all.patch"
    #    "${ps}/patches/ps-ui_pyroscope_all.patch"
    #    "${ps}/patches/pyroscope.patch"
    #    ./patches/ui_pyroscope_0.9.8.patch
    #    ./patches/pyroscope_cxxstd.patch
    #    ./patches/better_command_insert_error.patch # TODO add to other versions too
    #    ./patches/fast-session-loading-0.9.8.patch
    #    ./patches/rtorrent-ml-fixes-0.9.8.patch
    #  ];
    #  enableIPv6 = true;
    #};
  }
)
