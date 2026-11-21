{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, installShellFiles

, libtool
, autoconf
, autoconf-archive
, autoreconfHook
, automake
, cppunit
, ncurses
, libsigcxx_2_0
, lua ? null
, curl
, zlib
, openssl
, xmlrpc_c
, tinyxml-2
, libxml2
, systemd

, version ? null
, owner ? "rakshasa"
, rev ? "v${version}"
, hash ? ""

, libtorrent
, rtorrentPSVersion
, withAutoconfArchive ? !withAutoreconfHook
, withAutoreconfHook ? false
, enableDebug ? false
, enableShared ? true
, enableStatic ? false
, withLua ? lib.versionAtLeast version "0.16"
, enableSystemd ? false
, # better unicode support via tinyxml2
  withTinyxml2 ? true
, patches ? [ ]
, files ? { }
}:

assert withLua -> lua != null;

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

let
  # Supposedly fixes freezes with TCP trackers
  # https://github.com/rakshasa/rtorrent/issues/180
  curl-c-ares = curl.override { c-aresSupport = true; };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "rtorrent";
  version = (
    if !isNull version then version else
    libtorrent.version +
      lib.optionalString (rev != "v${version}") "+g${lib.substring 0 7 rev}"
  ) + "+PS${rtorrentPSVersion}";
  src = fetchFromGitHub {
    repo = "rtorrent";
    inherit rev hash owner;
  };
  inherit patches;

  configureFlags = [ "--disable-dependency-tracking" ]
    ++ lib.optional enableShared "--enable-shared"
    ++ lib.optional enableStatic "--enable-static"
    ++ lib.optional (!enableStatic) "--disable-static"
    ++ lib.optional enableDebug "--enable-debug"
    ++ lib.optional (!enableDebug) "--enable-debug=no"
    ++ lib.optional (!withTinyxml2) "--with-xmlrpc-c"
    ++ lib.optional withTinyxml2 "--with-xmlrpc-tinyxml2"
    ++ lib.optionals withLua [ "--with-lua" "LUA=${lua}/bin/lua" ]
    ++ lib.optional enableSystemd "--with-systemd";

  buildInputs = [
    cppunit
    libsigcxx_2_0
    libtool
    ncurses
    openssl
    libxml2
    zlib
    libtorrent
  ]
  ++ lib.optional (!withTinyxml2) xmlrpc_c
  ++ lib.optional withTinyxml2 tinyxml-2
  ++ lib.optional withLua lua
  ++ lib.optional (!lib.versionAtLeast finalAttrs.finalPackage.version "0.16") curl-c-ares
  ++ lib.optional enableSystemd systemd;

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ]
  ++ lib.optional withAutoreconfHook autoreconfHook
  ++ lib.optionals (!withAutoreconfHook) [
    autoconf
    automake
  ]
  ++ lib.optional withAutoconfArchive autoconf-archive;

  dontStrip = enableDebug;

  env = {
    # TODO clarify why this is needed
    RT_VERSION = lib.head (
      lib.match "([0-9.]+).*" (lib.versions.pad 3 finalAttrs.finalPackage.version)
    );
  };

  postUnpack = lib.concatMapAttrsStringSep "\n" (n: v: "cp ${v} $sourceRoot/src/${n}") files;
  postPatch = ''
    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ''${RT_VERSION//./ })
    sed -i "/AC_INIT/aAC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks)" configure.ac
    if ! grep "AC_DEFINE.*API_VERSION" configure.ac >/dev/null; then
      sed -i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1 AC_DEFINE(API_VERSION, 0, api version):" configure.ac
    fi
    sed -i -e 's/rTorrent \" /rTorrent ${finalAttrs.version} " /' src/ui/download_list.cc
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
  postCheck = ''
    src/rtorrent -h
  '';
  postInstall = ''
    installManPage doc/old/rtorrent.1
    mv doc/rtorrent.rc $out/share/rtorrent/rtorrent.rc
  ''
  + lib.optionalString enableDebug ''
    ln -s $src "$out/share/rtorrent-${finalAttrs.version}"
  '';

  doCheck = true;
  doInstallCheck = lib.versionAtLeast version "0.16";

  passthru = {
    libtorrentVersion = libtorrent.version;
    rtorrentVersion = finalAttrs.finalPackage.version;
  };

  enableParallelBuilding = true;

  meta = {
    description = "Ncurses client for libtorrent, ideal for use with screen, tmux, or dtach";
    homepage = "https://rakshasa.github.io/rtorrent/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "rtorrent";
  };
})
