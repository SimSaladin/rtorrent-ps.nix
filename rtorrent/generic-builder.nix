{ lib
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

, version ? null
, owner ? "rakshasa"
, rev ? "v${version}"
, hash ? ""

, libtorrent
, ps ? libtorrent.ps
, files ? { }
, enableDebug ? false
, enableIPv6 ? false # unused since 0.??.?
, enableAligned ? true
, enableLua ? null
, withAutoconfArchive ? !withAutoreconfHook
, withAutoreconfHook ? false

, nativeBuildInputs ? [ ]
, buildInputs ? [ ]
, configureFlags ? [ ]
, postUnpack ? ""
, postInstall ? ""
, patches ? [ ]
, env ? { }
, doCheck ? true
, doInstallCheck ? null
, enableParallelBuilding ? true
, passthru ? { }
, meta ? { }
}:

let
  defaultFiles = {
    command_pyroscope_cc = ./0.9.6/command_pyroscope.cc;
    ui_pyroscope_h = "${ps}/patches/ui_pyroscope.h";
    ui_pyroscope_cc = "${ps}/patches/ui_pyroscope.cc";
  };

  files' = if files != null then defaultFiles // files else { };

  # supposedly fixes freezes with TCP trackes.
  # https://github.com/rakshasa/rtorrent/issues/180
  curl-c-ares = curl.override { c-aresSupport = true; };
in

#assert enableLua -> lua != null;

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

stdenv.mkDerivation (finalAttrs:
let
  version' = if isNull version
    then libtorrent.libtorrentVersion + lib.optionalString (rev != "v${version'}") "+g${lib.substring 0 7 rev}"
    else version;
in
{
  pname = "rtorrent";
  version = version' + "+ps${ps.version}";

  src = fetchFromGitHub {
    repo = "rtorrent";
    inherit rev hash owner;
  };

  inherit patches doCheck enableParallelBuilding;

  enableLua = if isNull enableLua then lib.versionAtLeast version "0.16" else enableLua;
  doInstallCheck = if isNull doInstallCheck then lib.versionAtLeast version "0.16" else doInstallCheck;

  nativeBuildInputs = [ pkg-config ]
    ++ lib.optional withAutoreconfHook autoreconfHook
    ++ lib.optionals (!withAutoreconfHook) [ autoconf automake ]
    ++ lib.optional withAutoconfArchive autoconf-archive
    ++ nativeBuildInputs;

  buildInputs = [
    cppunit
    libsigcxx
    libtool
    ncurses
    openssl
    libxml2
    xmlrpc_c
    zlib
    libtorrent
  ]
  ++ lib.optional (!lib.versionAtLeast finalAttrs.finalPackage.version "0.16") curl-c-ares
  ++ lib.optional finalAttrs.enableLua lua
  ++ buildInputs;

  dontStrip = enableDebug;

  env = {
    # TODO clarify why this is needed
    RT_VERSION = lib.head (lib.match "([0-9.]+).*" (lib.versions.pad 3
    finalAttrs.finalPackage.version));
  } // env;

  passthru = {
    rtorrentVersion = finalAttrs.finalPackage.version;
    psVersion = ps.version;
    inherit (libtorrent) ps apiVersion libtorrentVersion;
  } // passthru;

  postUnpack = lib.concatMapAttrsStringSep "\n" (n: v: "cp ${v} $sourceRoot/src/${n}") files' + postUnpack;

  postPatch = ''
    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ''${RT_VERSION//./ })

    sed -i "/AC_INIT/aAC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks)" configure.ac
    if ! grep "AC_DEFINE.*API_VERSION" configure.ac >/dev/null; then
      sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(API_VERSION, 0, api version):" configure.ac
    fi

    sed -i -e 's/rTorrent \" /rTorrent ${finalAttrs.version} " /' \
      src/ui/download_list.cc
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
    ++ lib.optionals finalAttrs.enableLua [ "--with-lua" "LUA=${lua}/bin/lua" ]
    ++ configureFlags;

  postInstall = ''
    mkdir -p $out/share/man/man1 $out/share/doc/rtorrent
    mv doc/old/rtorrent.1 $out/share/man/man1/rtorrent.1
    mv doc/rtorrent.rc $out/share/doc/rtorrent/rtorrent.rc
  '' + lib.optionalString enableDebug ''
    ln -s $src "$out/share/rtorrent-${finalAttrs.version}"
  '' + postInstall;

  #postCheck = ''
  #  rtorrent -h
  #'';

  meta = {
    description = "Ncurses client for libtorrent, ideal for use with screen, tmux, or dtach";
    homepage = "https://rakshasa.github.io/rtorrent/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "rtorrent";
  } // meta;
})
