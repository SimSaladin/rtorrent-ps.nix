{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, autoreconfHook
, cppunit
, openssl
, libsigcxx
, zlib
, rtorrent-ps-src
}:
let
  ps = rtorrent-ps-src;

  generic = { version, rev ? "v${version}", sha256, ... }@attrs:
    let attrs' = builtins.removeAttrs attrs [ "version" "rev" "sha256" ];
    in

    # compiling with non-generic optimizations results in segfaults for some
    # reason.
    assert stdenv.hostPlatform.gcc == { };
    stdenv.mkDerivation ({
      pname = "libtorrent";
      version = "${attrs.version}-${ps.version}";

      src = fetchFromGitHub {
        owner = "rakshasa";
        repo = "libtorrent";
        inherit rev sha256;
      };

      nativeBuildInputs = [ pkg-config autoreconfHook ];
      buildInputs = [ cppunit openssl libsigcxx zlib ];
    } // attrs');

    mkLibtorrent = attrs: lib.makeOverridable generic attrs;
in
  {
    inherit mkLibtorrent;

    libtorrent_0_13_6 = mkLibtorrent {
      version = "0.13.6";
      sha256 = "1rvrxgb131snv9r6ksgzmd74rd9z7q46bhky0zazz7dwqqywffcp";
      patches = [
        "${ps.src}/patches/lt-base-cppunit-pkgconfig.patch"
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        "${ps.src}/patches/lt-ps-honor_system_file_allocate_all.patch"
        "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
    };

    libtorrent_0_13_7 = mkLibtorrent {
      version = "0.13.7";
      sha256 = "sha256-4E6+N5bHEuDQEZqiesUEeJiC3mXINoQX6LDryLhV+Ag=";
      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
        "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
    };

    libtorrent_0_13_8 = mkLibtorrent {
      version = "0.13.8";
      sha256 = "sha256-uSDzOU53i0aKm0C27In+zLAAHeKMu5av90DoN5YyvsA=";
      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
      ];
    };

    # has ipv6 support and memory crash fixes
    libtorrent_master = mkLibtorrent {
      version = "0.13.8-20230416";
      rev = "91f8cf4b0358d9b4480079ca7798fa7d9aec76b5";
      sha256 = "sha256-mEIrMwpWMCAA70Qb/UIOg8XTfg71R/2F4kb3QG38duU=";
      #version = "0.13.8-20-g53596afc";
      #rev = "53596afc5fae275b3fb5753a4bb2a1a7f7cf6a51";
      #sha256 = "sha256-gyl/jfbptHz/gHkkVGWShhv1Z7o9fa9nJIz27U2A6wg=";
      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
      ];
      configureFlags = [
        # https://github.com/rakshasa/rtorrent/issues/1237
        "--enable-aligned"
        "--with-posix-fallocate"
      ];
    };
  }
