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
  generic = { version, sha256, ... }@attrs:
    let attrs' = builtins.removeAttrs attrs [ "version" "sha256" ];
    in
    stdenv.mkDerivation (rec {
      name = "libtorrent";
      version = "${attrs.version}-${rtorrent-ps.version}";

      src = fetchFromGitHub {
        owner = "rakshasa";
        repo = "libtorrent";
        rev = "v${attrs.version}";
        inherit sha256;
      };

      nativeBuildInputs = [ pkg-config autoreconfHook ];
      buildInputs = [ cppunit openssl libsigcxx zlib ];
    } // attrs');
in
  rec {
    mkLibtorrent = attrs: lib.makeOverridable generic attrs;

    libtorrent_0_13_6 = mkLibtorrent {
      version = "0.13.6";
      sha256 = "1rvrxgb131snv9r6ksgzmd74rd9z7q46bhky0zazz7dwqqywffcp";
      patches = [
        "${rtorrent-ps.src}/patches/lt-base-cppunit-pkgconfig.patch"
        "${rtorrent-ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        "${rtorrent-ps.src}/patches/lt-ps-honor_system_file_allocate_all.patch"
        "${rtorrent-ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${rtorrent-ps.src}/patches/lt-open-ssl-1.1.patch";
    };

    libtorrent_0_13_7 = mkLibtorrent {
      version = "0.13.7";
      sha256 = "sha256-4E6+N5bHEuDQEZqiesUEeJiC3mXINoQX6LDryLhV+Ag=";
      patches = [
        "${rtorrent-ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
        "${rtorrent-ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${rtorrent-ps.src}/patches/lt-open-ssl-1.1.patch";
    };
  }
