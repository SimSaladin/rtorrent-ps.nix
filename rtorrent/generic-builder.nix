{ lib
, version
, rev ? "v${version}"
, hash
, RT_VERSION ? version
, ps
, files ? {
  command_pyroscope_cc = ./command_pyroscope.cc;
  ui_pyroscope_h = "${ps}/patches/ui_pyroscope.h";
  ui_pyroscope_cc = "${ps}/patches/ui_pyroscope.cc";
}
, stdenv
, fetchFromGitHub
, pkg-config
, libtool
, autoconf
, autoconf-archive
, autoreconfHook
, automake
, cppunit
, ncurses
, libsigcxx
, lua ? null
, curl
, zlib
, openssl
, xmlrpc_c
, libxml2
, libtorrent
, libtorrentVersion
, patches ? [ ]
, enableDebug ? false
, enableIPv6 ? false # true
, enableAligned ? true
, withAutoconfArchive ? !withAutoreconfHook
, withAutoreconfHook ? false
, enableLua ? false
, nativeBuildInputs ? [ ]
, buildInputs ? [ ]
, configureFlags ? [ ]
, env ? { }
, postUnpack ? ""
}:

assert enableLua -> lua != null;

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

let
  # supposedly fixes freezes with TCP trackes.
  # https://github.com/rakshasa/rtorrent/issues/180
  curl-c-ares = curl.override { c-aresSupport = true; };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "rtorrent";
  version = "${version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "rtorrent";
    inherit rev hash;
  };

  inherit patches;

  nativeBuildInputs = [ pkg-config ]
  ++ lib.optional withAutoreconfHook autoreconfHook
  ++ lib.optionals (!withAutoreconfHook) [ autoconf automake ]
  ++ lib.optional withAutoconfArchive autoconf-archive
  ++ nativeBuildInputs;

  buildInputs = [
    cppunit
    libsigcxx
    libtool
    libtorrent
    ncurses
    openssl
    libxml2
    xmlrpc_c
    zlib
  ]
  ++ lib.optional (!lib.versionAtLeast version "0.16") curl-c-ares
  ++ lib.optional enableLua lua
  ++ buildInputs;

  dontStrip = enableDebug;

  env = {
    inherit RT_VERSION; # TODO clarify why this is needed
  } // env;

  passthru = {
    inherit libtorrentVersion;
  };

  postUnpack = ''
    cp ${files.command_pyroscope_cc} $sourceRoot/src/command_pyroscope.cc # patched version of "${ps}/patches/ui_pyroscope.cc"
    cp ${files.ui_pyroscope_cc} $sourceRoot/src/ui_pyroscope.cc
    cp ${files.ui_pyroscope_h} $sourceRoot/src/ui_pyroscope.h
    ${postUnpack}
  '';

  postPatch = ''
    export ACLOCAL_PATH=$ACLOCAL_PATH:$PWD/scripts

    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ''${RT_VERSION//./ })
    sed -i "/AC_INIT/aAC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks)" configure.ac
    # sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" configure.ac
    grep "AC_DEFINE.*API_VERSION" configure.ac >/dev/null || sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(API_VERSION, 0, api version):" configure.ac
    sed -i -e 's/rTorrent \" VERSION/rTorrent ${finalAttrs.version} " VERSION/' src/ui/download_list.cc
  '';

  preConfigure = ''
    if [[ -x ./autogen.sh ]]; then
      ./autogen.sh
    else
      :
      ${lib.optionalString (!withAutoreconfHook) ''
      export ACLOCAL_PATH=$ACLOCAL_PATH:$PWD/scripts
      aclocal --force
      libtoolize --automake --copy --force
      autoheader
      automake --add-missing
      autoconf
      ''}
    fi
  '';

  postAutoreconf = ''
    automake --add-missing
    autoconf
  '';

  configureFlags = [ "--with-xmlrpc-c" ]
  ++ lib.optional enableIPv6 "--enable-ipv6"
  ++ lib.optional enableAligned "--enable-aligned=yes"
  ++ lib.optional enableDebug "--enable-debug"
  ++ lib.optional (!enableDebug) "--enable-debug=no"
  ++ lib.optionals enableLua [ "--with-lua" "LUA=${lua}/bin/lua" ]
  ++ configureFlags;

  postInstall = ''
    mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
    mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
    mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
  '' + lib.optionalString enableDebug ''
    ln -s $src "$out/share/rtorrent-${finalAttrs.version}"
  '';

  #postCheck = ''
  #  rtorrent -h
  #'';

  enableParallelBuilding = true;

  meta = {
    description = "Ncurses client for libtorrent, ideal for use with screen, tmux, or dtach";
    homepage = "https://rakshasa.github.io/rtorrent/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "rtorrent";
  };
})
