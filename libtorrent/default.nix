{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, autoreconfHook
, cppunit
, openssl
, libsigcxx
, zlib
, rtorrent-ps
}:
let
  ltVersion = "0.13.6";
in
stdenv.mkDerivation rec {
  name = "libtorrent";
  version = "${ltVersion}-${rtorrent-ps.version}";

  src = fetchFromGitHub {
    owner = "rakshasa";
    repo = "libtorrent";
    rev = "v${ltVersion}";
    sha256 = "1rvrxgb131snv9r6ksgzmd74rd9z7q46bhky0zazz7dwqqywffcp";
  };

  nativeBuildInputs = [ pkg-config autoreconfHook ];
  buildInputs = [ cppunit openssl libsigcxx zlib ];

  patches = [
    "${rtorrent-ps.src}/patches/lt-base-cppunit-pkgconfig.patch"
    "${rtorrent-ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
    "${rtorrent-ps.src}/patches/lt-ps-honor_system_file_allocate_all.patch"
    "${rtorrent-ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
    "${rtorrent-ps.src}/patches/lt-open-ssl-1.1.patch"
  ];
}
