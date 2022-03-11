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
, version
, sha256
, libtorrent
, patches ? [ ]
, withDebug ? false
}@attrs:
let
  ps = (import ../rtorrent-ps-src.nix { inherit fetchFromGitHub; }).default;
in

stdenv.mkDerivation rec {
  pname = "rtorrent";
  version = "${attrs.version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "rtorrent";
    rev = "v${attrs.version}";
    inherit sha256;
  };

  inherit patches;

  dontStrip = withDebug;

  postUnpack =
    let psExtraFiles = lib.filter (x: isNull (builtins.match ".*\.patch" x)) (lib.filesystem.listFilesRecursive "${ps.src}/patches");
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
}
