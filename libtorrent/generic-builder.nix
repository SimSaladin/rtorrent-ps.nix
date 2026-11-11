{ lib
, version ? null
, rev ? "v${version}"
, owner ? "rakshasa"
, hash ? null
, fetchFromGitHub
, stdenv
, pkg-config
, autoreconfHook
, cppunit
, openssl
, libsigcxx_2_0
, zlib
, curl
, withPosixFallocate ? stdenv.hostPlatform.isLinux
, enableAligned ? false
, enableStatic ? false
, c-aresSupport ? true
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

stdenv.mkDerivation (finalAttrs: {
  pname = "libtorrent";
  version =
    (if isNull version then getSrcVersion finalAttrs.finalPackage.src else version)
    + lib.optionalString (version == null || rev != "v${version}") "+g${lib.substring 0 7 rev}";

  src = fetchFromGitHub {
    repo = "libtorrent";
    inherit owner rev hash;
  };

  configureFlags = [ "--disable-dependency-tracking" ] ++
    lib.optional withPosixFallocate "--with-posix-fallocate" ++
    lib.optional enableAligned "--enable-aligned" ++
    lib.optional enableStatic "--enable-static";

  buildInputs = [ cppunit openssl libsigcxx_2_0 zlib ]
    ++ lib.optional (lib.versionAtLeast finalAttrs.finalPackage.version "0.16") (if c-aresSupport then curl.override { c-aresSupport = true; } else curl);

  nativeBuildInputs = [ pkg-config autoreconfHook ];

  enableParallelBuilding = true;

  doCheck = lib.versionAtLeast finalAttrs.finalPackage.version "0.16";

  doInstallCheck = lib.versionAtLeast finalAttrs.finalPackage.version "0.16";

  postAutoreconf = ''
    automake --add-missing
    autoconf
  '';

  meta = {
    description = "A BitTorrent library written in C++ for *nix, with focus on high performance and good code";
    homepage = "https://github.com/rakshasa/libtorrent";
    license = lib.licenses.gpl2Plus;
  };
})
