{ lib
, fetchFromGitHub
, automake111x
, rtorrent-ps-src
, callPackage
, libtorrents
}:
let
  ps = rtorrent-ps-src;

  mkRtorrent' = callPackage ./generic-builder.nix { inherit rtorrent-ps-src; };

  mkRtorrent = oattrs: lib.makeOverridable (mkRtorrent'.override oattrs);
in
{
  inherit mkRtorrent;

  rtorrent_0_9_6 = mkRtorrent { } {
    version = "0.9.6";
    sha256 = "0iyxmjr1984vs7hrnxkfwgrgckacqml0kv4bhj185w9bhjqvgfnf";
    libtorrent = libtorrents.libtorrent_0_13_6;
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
      ./rt-cxx11-compatibility.patch # Only 0.9.6, not 0.9.7
    ];
  };

  rtorrent_0_9_7 = mkRtorrent { } {
    version = "0.9.7";
    sha256 = "sha256-6qEWseLUItDNNPrZvxvPACQf01FVw4eaeseZ8tmYLSk=";
    libtorrent = libtorrents.libtorrent_0_13_7;
    patches = [
      ./ps-close_lowdisk_normal_all.patch
      "${ps.src}/patches/ps-dl-ui-find_all.patch"
      "${ps.src}/patches/ps-event-view_all.patch"
      "${ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-max_scgi_size_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      ./ps-throttle-steps_0.9.7.patch
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/ps-view-filter-by_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./ui_pyroscope_0.9.7.patch
      ./pyroscope_cxxstd.patch
      "${ps.src}/patches/backport_0.9.6_algorithm_median.patch" # rak::median is not in 0.9.7 either
    ];
  };

  rtorrent_0_9_8 = mkRtorrent { } {
    version = "0.9.8";
    sha256 = "sha256-4gx35bjzjUFdT2E9VGf/so7EQhaLQniUYgKQmVdwikE=";
    libtorrent = libtorrents.libtorrent_0_13_8;
    patches = [
      ./ps-close_lowdisk_normal_all.patch
      ./ps-dl-ui-find_0.9.8.patch
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-max_scgi_size_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./ui_pyroscope_0.9.8.patch
      ./pyroscope_cxxstd.patch
      ./better_command_insert_error.patch # TODO add to other versions too
    ];
  };

  # has ipv6 support and other fixes
  # In particular: https://github.com/rakshasa/rtorrent/pull/1169
  rtorrent_master = mkRtorrent { automake = automake111x; } {
    version = "0.9.8-20230416";
    rev = "1da0e3476dcabbf74b2e836d6b4c37b4d96bde09"; # Mar 16, 2023
    sha256 = "sha256-OXOZSMuNAU+VGwNyyfzcmkTRjDJq9HsKUNxZDYpSvFQ=";
    #version = "0.9.8-24-g1e40014";
    #rev = "1e400144828c937cb3a8cbd05191db9d95ee1676";
    #sha256 = "sha256-627aTFVbdeUgf/YRWMao01qcN/85lONTv+IC2hFF3z8=";
    libtorrent = libtorrents.libtorrent_master;
    RT_VERSION = "0.9.8";
    patches = [
      ./ps-close_lowdisk_normal_all.patch
      ./ps-dl-ui-find_0.9.8.patch
      "${ps.src}/patches/ps-import.return_all.patch"
      "${ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./ps-issue-515_all.patch
      "${ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps.src}/patches/ps-log_messages_all.patch"
      "${ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${ps.src}/patches/ps-silent-catch_all.patch"
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./ui_pyroscope_0.9.8.patch
      ./pyroscope_cxxstd.patch
      ./better_command_insert_error.patch # TODO add to other versions too
    ];
    enableIPv6 = true;
  };
}
