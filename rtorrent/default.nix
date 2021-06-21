{ lib, stdenv, fetchFromGitHub, pkg-config
, libtool, autoconf, automake, cppunit, ncurses, libsigcxx, curl, zlib, openssl, xmlrpc_c
, libtorrent, rtorrent-ps
}:
let
  rtVersion = "0.9.6";
  psPatches = lib.filesystem.listFilesRecursive "${rtorrent-ps.src}/patches";
  psExtraFiles = lib.filter (x: isNull (builtins.match ".*\.patch" x)) psPatches;
in
stdenv.mkDerivation rec {
    pname = "rtorrent";
    version = "${rtVersion}-${rtorrent-ps.version}";

    src = fetchFromGitHub {
      owner = "rakshasa";
      repo = "rtorrent";
      rev = "v${rtVersion}";
      sha256 = "0iyxmjr1984vs7hrnxkfwgrgckacqml0kv4bhj185w9bhjqvgfnf";
    };

    postUnpack = ''
      cp ${lib.concatStringsSep " " psExtraFiles} $sourceRoot/src
    '';

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [
      libtool autoconf automake cppunit
      libtorrent ncurses libsigcxx curl zlib openssl xmlrpc_c
    ];

    patches = [
        "${rtorrent-ps.src}/patches/backport_0.9.6_algorithm_median.patch"
        "${rtorrent-ps.src}/patches/ps-close_lowdisk_normal_all.patch"
        "${rtorrent-ps.src}/patches/ps-dl-ui-find_all.patch"
        "${rtorrent-ps.src}/patches/ps-event-view_all.patch"
        "${rtorrent-ps.src}/patches/ps-fix-double-slash-319_all.patch"
        "${rtorrent-ps.src}/patches/ps-fix-log-xmlrpc-close_all.patch"
        "${rtorrent-ps.src}/patches/ps-fix-sort-started-stopped-views_all.patch"
        "${rtorrent-ps.src}/patches/ps-fix-throttle-args_all.patch"
        "${rtorrent-ps.src}/patches/ps-handle-sighup-578_all.patch"
        "${rtorrent-ps.src}/patches/ps-import.return_all.patch"
        "${rtorrent-ps.src}/patches/ps-info-pane-is-default_all.patch"
        "${rtorrent-ps.src}/patches/ps-info-pane-xb-sizes_all.patch"
        "${rtorrent-ps.src}/patches/ps-issue-515_all.patch"
        "${rtorrent-ps.src}/patches/ps-item-stats-human-sizes_all.patch"
        "${rtorrent-ps.src}/patches/ps-log_messages_all.patch"
        "${rtorrent-ps.src}/patches/ps-max_scgi_size_all.patch"
        "${rtorrent-ps.src}/patches/ps-object_std-map-serialization_all.patch"
        "${rtorrent-ps.src}/patches/ps-silent-catch_all.patch"
        "${rtorrent-ps.src}/patches/ps-ssl_verify_host_all.patch"
        "${rtorrent-ps.src}/patches/ps-throttle-steps_all.patch"
        "${rtorrent-ps.src}/patches/ps-ui_pyroscope_all.patch"
        "${rtorrent-ps.src}/patches/ps-view-filter-by_all.patch"
        "${rtorrent-ps.src}/patches/pyroscope.patch"
        "${rtorrent-ps.src}/patches/rt-base-cppunit-pkgconfig.patch"
        "${rtorrent-ps.src}/patches/ui_pyroscope.patch"
        ./rt-cxx11-compatibility.patch
    ];

    postPatch = ''
      # Version handling
      sed -i -e 's/rTorrent \" VERSION/rTorrent ${version} " VERSION/' src/ui/download_list.cc
    '';

    preConfigure = "./autogen.sh";

    configureFlags = [ "--with-xmlrpc-c" "--with-posix-fallocate" ];

    postInstall = ''
      mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
      mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
      mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
    '';

  }
