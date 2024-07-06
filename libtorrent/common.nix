{ lib
, fetchFromGitHub
, ps
, version
, rev ? "v${version}"
, sha256
, buildInputs ? [ ]
, nativeBuildInputs ? [ ]
, patches ? [ ]
}:

{ stdenv
, pkg-config
, autoreconfHook
, cppunit
, openssl
, libsigcxx
, zlib
, withPosixFallocate ? stdenv.hostPlatform.isLinux
, enableAligned ? false
}:

# compiling with non-generic optimizations results in segfaults for some
# reason.
assert stdenv.hostPlatform.isx86_64 -> stdenv.hostPlatform.gcc.arch or "x86-64" == "x86-64";

stdenv.mkDerivation {
  pname = "libtorrent";
  version = "${version}-${ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "libtorrent";
    inherit rev sha256;
  };

  inherit patches;

  configureFlags =
    lib.optional withPosixFallocate "--with-posix-fallocate"
    ++ lib.optional enableAligned "--enable-aligned"
  ;

  nativeBuildInputs = nativeBuildInputs ++ [ pkg-config autoreconfHook ];

  buildInputs = buildInputs ++ [ cppunit openssl libsigcxx zlib ];
}
