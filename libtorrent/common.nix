{ lib
, ps
, version
, rev ? "v${version}"
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
}:

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

let
  curl' = curl.override { c-aresSupport = true; };
in

stdenv.mkDerivation (_: {
  pname = "libtorrent";
  version = "${version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "libtorrent";
    inherit rev hash;
  };

  inherit patches;

  buildInputs = [ cppunit openssl libsigcxx zlib ]
    ++ lib.optionals (lib.versionAtLeast version "0.16") [ curl' ]
    ++ buildInputs;

  nativeBuildInputs = [ pkg-config autoreconfHook ] ++ nativeBuildInputs;

  postAutoreconf = ''
    automake --add-missing
    autoconf
  '';

  configureFlags =
    lib.optional withPosixFallocate "--with-posix-fallocate" ++
    lib.optional enableAligned "--enable-aligned";

  inherit postInstall;

  passthru = {
    rtorrentPSVersion = ps.version;
  };

  enableParallelBuilding = true;

  meta = {
    description = "A BitTorrent library written in C++ for *nix, with focus on high performance and good code";
    homepage = "https://github.com/rakshasa/libtorrent";
    license = lib.licenses.gpl2Plus;
  };
})
