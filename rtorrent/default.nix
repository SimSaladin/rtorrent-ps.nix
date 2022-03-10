{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, libtool
, autoconf
, automake
, cppunit
, ncurses
, libsigcxx
, curl
, zlib
, openssl
, xmlrpc_c
, libtorrent_0_13_6
, libtorrent_0_13_7
, rtorrent-ps
, withDebug ? false
}:
let
  generic = { version, sha256, libtorrent, ... }@attrs:
    let attrs' = builtins.removeAttrs attrs [ "version" "sha256" "libtorrent" ];
    in
    stdenv.mkDerivation (rec {
      pname = "rtorrent";
      version = "${attrs.version}-${rtorrent-ps.version}";

      src = fetchFromGitHub {
        owner = "rakshasa";
        repo = "rtorrent";
        rev = "v${attrs.version}";
        inherit sha256;
      };

      dontStrip = withDebug;

      postUnpack =
        let psExtraFiles = lib.filter (x: isNull (builtins.match ".*\.patch" x)) (lib.filesystem.listFilesRecursive "${rtorrent-ps.src}/patches");
        in ''cp ${lib.concatStringsSep " " psExtraFiles} $sourceRoot/src'';

      nativeBuildInputs = [ pkg-config ];
      buildInputs = [
        libtool
        autoconf
        automake
        cppunit
        libtorrent
        ncurses
        libsigcxx
        curl
        zlib
        openssl
        xmlrpc_c
      ];

      RT_VERSION = attrs.version;

      postPatch = ''
        # Version handling
        RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ''${RT_VERSION//./ })
        sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" configure.ac
        grep "AC_DEFINE.*API_VERSION" configure.ac >/dev/null || sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(API_VERSION, 0, api version):" configure.ac
        sed -i -e 's/rTorrent \" VERSION/rTorrent ${version} " VERSION/' src/ui/download_list.cc
      '';

      preConfigure = ''
        ./autogen.sh
      '';

      # todo: --enable-ipv6 ?
      configureFlags = [ "--with-xmlrpc-c" "--with-posix-fallocate" ];

      postInstall = ''
        mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
        mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
        mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
      '' + lib.optionalString withDebug ''
        cp -r ../src $out/
      '';
    } // attrs');

in
rec {
  mkRtorrent = attrs: lib.makeOverridable generic attrs;

  rtorrent_0_9_6 = mkRtorrent {
    version = "0.9.6";
    sha256 = "0iyxmjr1984vs7hrnxkfwgrgckacqml0kv4bhj185w9bhjqvgfnf";
    libtorrent = libtorrent_0_13_6;
    patches = [
      "${rtorrent-ps.src}/patches/backport_0.9.6_algorithm_median.patch"
      "${rtorrent-ps.src}/patches/ps-close_lowdisk_normal_all.patch"
      "${rtorrent-ps.src}/patches/ps-dl-ui-find_all.patch"
      "${rtorrent-ps.src}/patches/ps-event-view_all.patch"
      "${rtorrent-ps.src}/patches/ps-fix-double-slash-319_all.patch"
      "${rtorrent-ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${rtorrent-ps.src}/patches/ps-fix-sort-started-stopped-views_all.patch" # not 0.9.7
      "${rtorrent-ps.src}/patches/ps-fix-throttle-args_all.patch" # not 0.9.7
      "${rtorrent-ps.src}/patches/ps-handle-sighup-578_all.patch" # not 0.9.7
      "${rtorrent-ps.src}/patches/ps-import.return_all.patch"
      "${rtorrent-ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${rtorrent-ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      "${rtorrent-ps.src}/patches/ps-issue-515_all.patch"
      "${rtorrent-ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${rtorrent-ps.src}/patches/ps-log_messages_all.patch"
      "${rtorrent-ps.src}/patches/ps-max_scgi_size_all.patch"
      "${rtorrent-ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${rtorrent-ps.src}/patches/ps-silent-catch_all.patch"
      "${rtorrent-ps.src}/patches/ps-ssl_verify_host_all.patch" # not 0.9.7
      "${rtorrent-ps.src}/patches/ps-throttle-steps_all.patch"
      "${rtorrent-ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${rtorrent-ps.src}/patches/ps-view-filter-by_all.patch"
      "${rtorrent-ps.src}/patches/pyroscope.patch"
      "${rtorrent-ps.src}/patches/rt-base-cppunit-pkgconfig.patch" # not 0.9.7
      "${rtorrent-ps.src}/patches/ui_pyroscope.patch"
      ./rt-cxx11-compatibility.patch # Only 0.9.6, not 0.9.7
    ];
  };

  rtorrent_0_9_7 = mkRtorrent {
    version = "0.9.7";
    sha256 = "sha256-6qEWseLUItDNNPrZvxvPACQf01FVw4eaeseZ8tmYLSk=";
    libtorrent = libtorrent_0_13_7;
    patches = [
      ./ps-close_lowdisk_normal_all.patch
      "${rtorrent-ps.src}/patches/ps-dl-ui-find_all.patch"
      "${rtorrent-ps.src}/patches/ps-event-view_all.patch"
      "${rtorrent-ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
      "${rtorrent-ps.src}/patches/ps-import.return_all.patch"
      "${rtorrent-ps.src}/patches/ps-info-pane-is-default_all.patch"
      "${rtorrent-ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
      ./ps-issue-515_all.patch
      "${rtorrent-ps.src}/patches/ps-item-stats-human-sizes_all.patch"
      "${rtorrent-ps.src}/patches/ps-log_messages_all.patch"
      "${rtorrent-ps.src}/patches/ps-max_scgi_size_all.patch"
      "${rtorrent-ps.src}/patches/ps-object_std-map-serialization_all.patch"
      "${rtorrent-ps.src}/patches/ps-silent-catch_all.patch"
      ./ps-throttle-steps_all.patch
      "${rtorrent-ps.src}/patches/ps-ui_pyroscope_all.patch"
      "${rtorrent-ps.src}/patches/ps-view-filter-by_all.patch"
      "${rtorrent-ps.src}/patches/pyroscope.patch"
      ./ui_pyroscope.patch
      ./pyroscope_cxxstd.patch
      "${rtorrent-ps.src}/patches/backport_0.9.6_algorithm_median.patch" # rak::median is not in 0.9.7 either
    ];
  };
}
