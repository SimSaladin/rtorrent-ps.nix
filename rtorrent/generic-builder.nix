{ version
, rev ? "v${version}"
, hash
, RT_VERSION ? version
, patches ? [ ]
, rtorrent-ps-src
}@attrs:

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
, libxml2
, libtorrent
, withDebug ? false
, enableIPv6 ? false # true
}:

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

let
  ps = rtorrent-ps-src;

  # supposedly fixes freezes with TCP trackes.
  # https://github.com/rakshasa/rtorrent/issues/180
  curl-c-ares = curl.override { c-aresSupport = true; };
in

stdenv.mkDerivation rec {
  pname = "rtorrent";
  version = "${attrs.version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "rtorrent";
    inherit rev hash;
  };

  inherit patches;

  nativeBuildInputs = [
    autoconf-archive
    #autoreconfHook
    autoconf # XXX use autoreconfHook?
    automake # XXX use autoreconfHook?
    pkg-config
  ];

  buildInputs = [
    cppunit
    curl-c-ares
    libsigcxx
    libtool
    libtorrent
    ncurses
    openssl
    libxml2
    xmlrpc_c
    zlib
  ];

  dontStrip = withDebug;

  env = {
    inherit RT_VERSION; # TODO clarify why this is needed
  };

  postUnpack = ''
    cp ${./command_pyroscope.cc} $sourceRoot/src/command_pyroscope.cc # patched version of "${ps.src}/patches/ui_pyroscope.cc"
    cp ${ lib.concatStringsSep " " [
      "${ps.src}/patches/ui_pyroscope.cc"
      "${ps.src}/patches/ui_pyroscope.h"
    ]} $sourceRoot/src
  '';

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
    #"--enable-aligned" # https://github.com/rakshasa/libtorrent/issues/244
  ] ++ lib.optional enableIPv6 "--enable-ipv6";

  postInstall = ''
    mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
    mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
    mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
  '' + lib.optionalString withDebug ''
    ln -s $src "$out/share/rtorrent-${version}"
  '';

  #postCheck = ''
  #  rtorrent -h
  #'';

  meta = {
    description = "Ncurses client for libtorrent, ideal for use with screen, tmux, or dtach";
    homepage = "https://rakshasa.github.io/rtorrent/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "rtorrent";
  };
}
