{ lib
, fetchFromGitHub
, callPackage
, openssl
, udns
, rtorrent-ps-src
}:
let
  ps = rtorrent-ps-src;

  common = args:
    callPackage (import ./common.nix ({ inherit lib fetchFromGitHub ps; } // args)) { };
in
  lib.recurseIntoAttrs (rec {
    libtorrent_0_13_6 = common {
      version = "0.13.6";
      sha256 = "1rvrxgb131snv9r6ksgzmd74rd9z7q46bhky0zazz7dwqqywffcp";

      patches = [
        "${ps.src}/patches/lt-base-cppunit-pkgconfig.patch"
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        "${ps.src}/patches/lt-ps-honor_system_file_allocate_all.patch"
        "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
    };

    libtorrent_0_13_7 = common {
      version = "0.13.7";
      sha256 = "sha256-4E6+N5bHEuDQEZqiesUEeJiC3mXINoQX6LDryLhV+Ag=";

      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
        "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
      ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
    };

    libtorrent_0_13_8 = common {
      version = "0.13.8";
      sha256 = "sha256-uSDzOU53i0aKm0C27In+zLAAHeKMu5av90DoN5YyvsA=";
      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
      ];
    };

    # - ipv6 support
    # - memory crash fixes
    # - udns
    # - scanf crash fix
    libtorrent_master = (common {
      version = "0.13.8-20230416";
      rev = "91f8cf4b0358d9b4480079ca7798fa7d9aec76b5";
      sha256 = "sha256-mEIrMwpWMCAA70Qb/UIOg8XTfg71R/2F4kb3QG38duU=";
      patches = [
        "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
        ./lt-ps-honor_system_file_allocate_0.13.7.patch
        ./libtorrent-udns-0.13.8.patch # from https://github.com/swizzin/swizzin
        ./libtorrent-scanf-0.13.8.patch # from https://github.com/swizzin/swizzin
        ./lookup-cache-0.13.8.patch
      ];
      buildInputs = [ udns ];
    }).override {
      enableAligned = true; # https://github.com/rakshasa/rtorrent/issues/1237
    };

    latest = libtorrent_master;
  })
