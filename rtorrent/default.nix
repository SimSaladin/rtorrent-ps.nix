{ lib
, pkgsGeneric
, callPackage
, lua5_4
, ps
, libtorrentPackages
}:

let
  rtorrentBuild = args0: let
    args = {
      inherit (pkgsGeneric) stdenv;
      libtorrent = libtorrentPackages.${
        lib.versionToName "${args0.libtorrentVersion}/PS${ps.version}"
      };
    } // lib.removeAttrs args0 [ "libtorrentVersion" ];
  in
    callPackage ./generic-builder.nix args;
in
lib.recurseIntoAttrs (lib.fix (_self: lib.mapSuffix "PS${ps.version}" {

  "0.9.6" = rtorrentBuild {
    version = "0.9.6";
    libtorrentVersion = "0.13.6";
    hash = "sha256-zrq3sYQr8YKChIvsCWjFTE328uNudpvh0ZugFLKs3Uc=";
    patches = [
      "${ps}/patches/backport_0.9.6_algorithm_median.patch"
      "${ps}/patches/ps-close_lowdisk_normal_all.patch"
      "${ps}/patches/ps-dl-ui-find_all.patch"
      "${ps}/patches/ps-event-view_all.patch"
      "${ps}/patches/ps-fix-double-slash-319_all.patch"
      "${ps}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${ps}/patches/ps-fix-sort-started-stopped-views_all.patch" # not 0.9.7
      "${ps}/patches/ps-fix-throttle-args_all.patch" # not 0.9.7
      "${ps}/patches/ps-handle-sighup-578_all.patch" # not 0.9.7
      "${ps}/patches/ps-import.return_all.patch"
      "${ps}/patches/ps-info-pane-is-default_all.patch"
      "${ps}/patches/ps-info-pane-xb-sizes_all.patch"
      "${ps}/patches/ps-issue-515_all.patch"
      "${ps}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps}/patches/ps-log_messages_all.patch"
      "${ps}/patches/ps-max_scgi_size_all.patch"
      "${ps}/patches/ps-object_std-map-serialization_all.patch"
      "${ps}/patches/ps-silent-catch_all.patch"
      "${ps}/patches/ps-ssl_verify_host_all.patch" # not 0.9.7
      "${ps}/patches/ps-throttle-steps_all.patch"
      "${ps}/patches/ps-ui_pyroscope_all.patch"
      "${ps}/patches/ps-view-filter-by_all.patch"
      "${ps}/patches/pyroscope.patch"
      "${ps}/patches/rt-base-cppunit-pkgconfig.patch" # not 0.9.7
      "${ps}/patches/ui_pyroscope.patch"
      ./patches/rt-cxx11-compatibility.patch # Only 0.9.6, not 0.9.7
    ];
  };

  "0.9.7" = rtorrentBuild {
    version = "0.9.7";
    libtorrentVersion = "0.13.7";
    hash = "sha256-6qEWseLUItDNNPrZvxvPACQf01FVw4eaeseZ8tmYLSk=";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      "${ps}/patches/ps-dl-ui-find_all.patch"
      "${ps}/patches/ps-event-view_all.patch"
      "${ps}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${ps}/patches/ps-import.return_all.patch"
      "${ps}/patches/ps-info-pane-is-default_all.patch"
      "${ps}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps}/patches/ps-log_messages_all.patch"
      "${ps}/patches/ps-max_scgi_size_all.patch"
      "${ps}/patches/ps-object_std-map-serialization_all.patch"
      "${ps}/patches/ps-silent-catch_all.patch"
      ./patches/ps-throttle-steps_0.9.7.patch
      "${ps}/patches/ps-ui_pyroscope_all.patch"
      "${ps}/patches/ps-view-filter-by_all.patch"
      "${ps}/patches/pyroscope.patch"
      ./patches/ui_pyroscope_0.9.7.patch
      ./patches/pyroscope_cxxstd.patch
      "${ps}/patches/backport_0.9.6_algorithm_median.patch" # rak::median is not in 0.9.7 either
    ];
  };

  "0.9.8" = rtorrentBuild {
    version = "0.9.8";
    libtorrentVersion = "0.13.8";
    hash = "sha256-4gx35bjzjUFdT2E9VGf/so7EQhaLQniUYgKQmVdwikE=";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      ./patches/ps-dl-ui-find_0.9.8.patch
      "${ps}/patches/ps-import.return_all.patch"
      "${ps}/patches/ps-info-pane-is-default_all.patch"
      "${ps}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps}/patches/ps-log_messages_all.patch"
      "${ps}/patches/ps-max_scgi_size_all.patch"
      "${ps}/patches/ps-object_std-map-serialization_all.patch"
      "${ps}/patches/ps-silent-catch_all.patch"
      "${ps}/patches/ps-ui_pyroscope_all.patch"
      "${ps}/patches/pyroscope.patch"
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
    libtorrentVersion = "0.13.8-20230416";
    patches = [
      ./patches/ps-close_lowdisk_normal_all.patch
      ./patches/ps-dl-ui-find_0.9.8.patch
      "${ps}/patches/ps-import.return_all.patch"
      "${ps}/patches/ps-info-pane-is-default_all.patch"
      "${ps}/patches/ps-info-pane-xb-sizes_all.patch"
      ./patches/ps-issue-515_all.patch
      "${ps}/patches/ps-item-stats-human-sizes_all.patch"
      "${ps}/patches/ps-log_messages_all.patch"
      "${ps}/patches/ps-object_std-map-serialization_all.patch"
      "${ps}/patches/ps-silent-catch_all.patch"
      "${ps}/patches/ps-ui_pyroscope_all.patch"
      "${ps}/patches/pyroscope.patch"
      ./patches/ui_pyroscope_0.9.8.patch
      ./patches/pyroscope_cxxstd.patch
      ./patches/better_command_insert_error.patch # TODO add to other versions too
      ./patches/fast-session-loading-0.9.8.patch
      ./patches/rtorrent-ml-fixes-0.9.8.patch
    ];
    enableIPv6 = true;
  };

  "0.16.0-677f8f4" = rtorrentBuild {
    version = "0.16.0-677f8f4";
    rev = "677f8f45c841d308df7c77b0b23ce4fd7a8a7a16";
    hash = "sha256-iC2+gdbh6Rvch7SQhQ8F/zdZuWmJN+KrObN3qBS0bAE=";
    libtorrentVersion = "0.16.0-5efa83a";
    enableIPv6 = true;
    withAutoreconfHook = true;
    enableLua = true;
    lua = lua5_4;
    patches = [
      "${ps}/patches/ps-import.return_all.patch"
      ./patches/ps-dl-ui-find_0.16.0.patch
      "${ps}/patches/pyroscope.patch"
      "${ps}/patches/ps-ui_pyroscope_all.patch"
      ./patches/ui_pyroscope_0.16.0.patch
    ];
    files = {
      command_pyroscope_cc = ./0.16.0-677f8f4/command_pyroscope.cc;
      ui_pyroscope_h = ./0.16.0-677f8f4/ui_pyroscope.h;
      ui_pyroscope_cc = ./0.16.0-677f8f4/ui_pyroscope.cc;
    };
    postUnpack = ''
      cp -v ${./0.16.0-677f8f4/color_map.h} $sourceRoot/src/display/color_map.h
    '';
  };


  "0.16.0-next" = rtorrentBuild {
    version = "0.16.0-next";
    rev = "a5fbcc2e2cf71bed2a9757183556c4a6101a2db2";
    hash = "sha256-QrM8j+IRqpp6nSy73WpI5kgkpovohH70t0+t90emJ5k=";
    owner = "SimSaladin";
    libtorrentVersion = "0.16.0-next";
    enableIPv6 = true;
    withAutoreconfHook = true;
    enableLua = true;
    lua = lua5_4;
    patches = [ ];
    files = null;
  };
}))
