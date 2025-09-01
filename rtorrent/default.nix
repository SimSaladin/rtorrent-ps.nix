{ lib
, pkgsGeneric
, callPackage
#, automake111x
, rtorrent-ps-src
, libtorrentPackages
}:

let
  ps = rtorrent-ps-src;

  callFun = g: f: args: g f (lib.intersectAttrs (lib.functionArgs f) args);

  rtorrentBuild = args0: let
    args = {
      inherit rtorrent-ps-src;
      inherit (pkgsGeneric) stdenv;
      libtorrent = libtorrentPackages.${args0.libtorrentVersion};
    } // args0;
    builder = callFun (f: args: f args) (import ./generic-builder.nix) args;
    pkg = callFun callPackage builder args;
  in
    pkg;
in
lib.recurseIntoAttrs (lib.fix (self: {

  rtorrent_0_96 = self."0.9.6";
  rtorrent_0_97 = self."0.9.7";
  rtorrent_0_98 = self."0.9.8";
  rtorrent_master = self."0.9.8-20230416";
  latest = self.rtorrent_master;

  "0.9.6" = rtorrentBuild {
    version = "0.9.6";
    libtorrentVersion = "0.13.6";
    hash = "sha256-zrq3sYQr8YKChIvsCWjFTE328uNudpvh0ZugFLKs3Uc=";
    patches = [
      "${ps.src}/patches/backport_0.9.6_algorithm_median.patch"
      "${ps.src}/patches/ps-close_lowdisk_normal_all.patch"
      "${ps.src}/patches/ps-dl-ui-find_all.patch"
      "${ps.src}/patches/ps-event-view_all.patch"
      "${ps.src}/patches/ps-fix-double-slash-319_all.patch"
      "${ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${ps.src}/patches/ps-fix-sort-started-stopped-views_all.patch" # not 0.9.7
      "${ps.src}/patches/ps-fix-throttle-args_all.patch" # not 0.9.7
      "${ps.src}/patches/ps-handle-sighup-578_all.patch" # not 0.9.7
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      "${ps.src}/patches/ps-issue-515_all.patch"
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-max_scgi_size_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      "${ps.src}/patches/ps-ssl_verify_host_all.patch" # not 0.9.7
      "${ps.src}/patches/ps-throttle-steps_all.patch"
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/ps-view-filter-by_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      "${ps.src}/patches/rt-base-cppunit-pkgconfig.patch" # not 0.9.7
      "${ps.src}/patches/ui_pyroscope.patch"
      ./patches/rt-cxx11-compatibility.patch # Only 0.9.6, not 0.9.7
    ];
  };

  "0.9.7" = rtorrentBuild {
    version = "0.9.7";
    libtorrentVersion = "0.13.7";
    hash = "sha256-6qEWseLUItDNNPrZvxvPACQf01FVw4eaeseZ8tmYLSk=";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      "${ps.src}/patches/ps-dl-ui-find_all.patch"
      "${ps.src}/patches/ps-event-view_all.patch"
      "${ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-max_scgi_size_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      ./patches/ps-throttle-steps_0.9.7.patch
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/ps-view-filter-by_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./patches/ui_pyroscope_0.9.7.patch
      ./patches/pyroscope_cxxstd.patch
      "${ps.src}/patches/backport_0.9.6_algorithm_median.patch" # rak::median is not in 0.9.7 either
    ];
  };

  "0.9.8" = rtorrentBuild {
    version = "0.9.8";
    libtorrentVersion = "0.13.8";
    hash = "sha256-4gx35bjzjUFdT2E9VGf/so7EQhaLQniUYgKQmVdwikE=";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      ./patches/ps-dl-ui-find_0.9.8.patch
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-max_scgi_size_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./patches/ui_pyroscope_0.9.8.patch
      ./patches/pyroscope_cxxstd.patch
      ./patches/better_command_insert_error.patch # TODO add to other versions too
    ];
  };

  # has ipv6 support and other fixes
  # In particular: https://github.com/rakshasa/rtorrent/pull/1169
  "0.9.8-20230416" = rtorrentBuild {
    version = "0.9.8-20230416";
    rev = "1da0e3476dcabbf74b2e836d6b4c37b4d96bde09"; # Mar 16, 2023
    hash = "sha256-OXOZSMuNAU+VGwNyyfzcmkTRjDJq9HsKUNxZDYpSvFQ=";
    RT_VERSION = "0.9.8";
    libtorrentVersion = "0.13.8-20230416";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      ./patches/ps-dl-ui-find_0.9.8.patch
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./patches/ui_pyroscope_0.9.8.patch
      ./patches/pyroscope_cxxstd.patch
      ./patches/better_command_insert_error.patch # TODO add to other versions too
      ./patches/fast-session-loading-0.9.8.patch
      ./patches/rtorrent-ml-fixes-0.9.8.patch
    ];
    #automake = automake111x;
    enableIPv6 = true;
  };
}))
