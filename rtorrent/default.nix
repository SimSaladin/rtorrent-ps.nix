{ lib
, pkgs
, fetchFromGitHub
}:
let
  ps = (import ../rtorrent-ps-src.nix { inherit fetchFromGitHub; }).default;
in
rec {
  mkRtorrent = pkgs.callPackage ./generic-builder.nix;

  rtorrent_0_9_6 = mkRtorrent {
    version = "0.9.6";
    sha256 = "0iyxmjr1984vs7hrnxkfwgrgckacqml0kv4bhj185w9bhjqvgfnf";
    libtorrent = pkgs.libtorrent_0_13_6;
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

  rtorrent_0_9_7 = mkRtorrent {
    version = "0.9.7";
    sha256 = "sha256-6qEWseLUItDNNPrZvxvPACQf01FVw4eaeseZ8tmYLSk=";
    libtorrent = pkgs.libtorrent_0_13_7;
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
      ./ps-throttle-steps_all.patch
      "${ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${ps.src}/patches/ps-view-filter-by_all.patch"
      "${ps.src}/patches/pyroscope.patch"
      ./ui_pyroscope.patch
      ./pyroscope_cxxstd.patch
      "${ps.src}/patches/backport_0.9.6_algorithm_median.patch" # rak::median is not in 0.9.7 either
    ];
  };
}
