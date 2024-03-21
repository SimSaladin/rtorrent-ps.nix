{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, libtool
, autoconf
, autoconf-archive
, automake
#, autoreconfHook
, cppunit
, ncurses
, libsigcxx
, curl
, zlib
, openssl
, xmlrpc_c
, rtorrent-ps-src
}:

{ version
, sha256
, rev ? "v${version}"
, RT_VERSION ? version
, libtorrent
, patches ? [ ]
, withDebug ? false
, enableIPv6 ? false # true
}@attrs:

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.gcc == { };

let
  ps = rtorrent-ps-src;

  # supposedly fixes freezes with TCP trackes.
  # https://github.com/rakshasa/rtorrent/issues/180
  curl' = curl.override ({ c-aresSupport = true; });
in

stdenv.mkDerivation rec {
  pname = "rtorrent";
  version = "${attrs.version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "rtorrent";
    inherit rev sha256;
  };

  inherit patches;

  dontStrip = withDebug;

  postUnpack = ''
    cp ${./command_pyroscope.cc} $sourceRoot/src/command_pyroscope.cc # patched version of "${ps.src}/patches/ui_pyroscope.cc"
    cp ${ lib.concatStringsSep " " [
      "${ps.src}/patches/ui_pyroscope.cc"
      "${ps.src}/patches/ui_pyroscope.h"
    ]} $sourceRoot/src
  '';

  nativeBuildInputs = [
    autoconf-archive
    #autoreconfHook
    autoconf # XXX use autoreconfHook?
    automake # XXX use autoreconfHook?
    pkg-config
  ];

  buildInputs = [
    cppunit
    curl'
    libsigcxx
    libtool
    libtorrent
    ncurses
    openssl
    xmlrpc_c
    zlib
  ];

  # TODO clarify why this is needed
  inherit RT_VERSION;

  postPatch = ''
    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ''${RT_VERSION//./ })
    sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" configure.ac
    grep "AC_DEFINE.*API_VERSION" configure.ac >/dev/null || sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(API_VERSION, 0, api version):" configure.ac
    sed -i -e 's/rTorrent \" VERSION/rTorrent ${version} " VERSION/' src/ui/download_list.cc
  '';

  preConfigure = ''
    if [[ -x ./autogen.sh ]]; then
      ./autogen.sh
    else
      export ACLOCAL_PATH=$ACLOCAL_PATH:$PWD/scripts
      aclocal --force
      libtoolize --automake --copy --force
      autoheader
      automake --add-missing
      autoconf
    fi
  '';

  configureFlags = [
    "--with-xmlrpc-c"
  ] ++ lib.optional enableIPv6 "--enable-ipv6";

  #postCheck = ''
  #  rtorrent -h
  #'';

  postInstall = ''
    mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
    mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
    mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
  '' + lib.optionalString withDebug ''
    ln -s $src "$out/share/rtorrent-${version}"
  '';
}
