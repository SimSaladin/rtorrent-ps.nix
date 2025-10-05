{ lib
, ps
, version ? null
, rev ? "v${version}"
, owner ? "rakshasa"
, hash
, patches ? [ ]
, buildInputs ? [ ]
, nativeBuildInputs ? [ ]
, postInstall ? null
, fetchFromGitHub
, stdenv
, pkg-config
, autoreconfHook
, cppunit
, openssl
, libsigcxx
, zlib
, curl
, withPosixFallocate ? stdenv.hostPlatform.isLinux
, enableAligned ? false
, c-aresSupport ? true
, configureFlags ? [ ]
, doCheck ? null
, doInstallCheck ? null
, passthru ? { }
, meta ? { }
, enableParallelBuilding ? true
}:

let
  getSrcVersion = src: lib.pipe (src + "/configure.ac") [
    lib.fileContents
    (lib.match ".*AC_INIT...libtorrent..,..([0-9.]+).*")
    lib.head
  ];
in

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

stdenv.mkDerivation (finalAttrs:

let
  srcVersion = getSrcVersion finalAttrs.finalPackage.src;

  version' = (if isNull version then srcVersion else version)
    + lib.optionalString (version == null || rev != "v${version}") "+g${lib.substring 0 7 rev}";
in
{
  pname = "libtorrent";
  version = version' + "+PS" + ps.version;

  src = fetchFromGitHub {
    repo = "libtorrent";
    inherit owner rev hash;
  };

  configureFlags =
    lib.optional withPosixFallocate "--with-posix-fallocate" ++
    lib.optional enableAligned "--enable-aligned" ++
    configureFlags;

  buildInputs = [ cppunit openssl libsigcxx zlib ]
    ++ lib.optional (lib.versionAtLeast finalAttrs.finalPackage.version "0.16") (if c-aresSupport then curl.override { c-aresSupport = true; } else curl)
    ++ buildInputs;

  nativeBuildInputs = [ pkg-config autoreconfHook ] ++ nativeBuildInputs;

  inherit patches postInstall enableParallelBuilding;

  doCheck = if isNull doCheck then lib.versionAtLeast finalAttrs.finalPackage.version "0.16" else doCheck;

  doInstallCheck = if isNull doInstallCheck then lib.versionAtLeast finalAttrs.finalPackage.version "0.16" else doInstallCheck;

  postAutoreconf = ''
    automake --add-missing
    autoconf
  '';

  passthru = {
    inherit ps;
    apiVersion = srcVersion;
    libtorrentVersion = version';
    rtorrentPSVersion = ps.version;
  } // passthru;

  meta = {
    description = "A BitTorrent library written in C++ for *nix, with focus on high performance and good code";
    homepage = "https://github.com/rakshasa/libtorrent";
    license = lib.licenses.gpl2Plus;
  } // meta;
})
