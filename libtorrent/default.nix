{ lib
, pkgsGeneric
, callPackage
, openssl
, udns
, rtorrent-ps-src
}:
let
  ps = rtorrent-ps-src;

  common = args: let
    mkPkg = import ./common.nix ({ inherit ps; } // args);
  in
    callPackage mkPkg { inherit (pkgsGeneric) stdenv; };
in
lib.recurseIntoAttrs (lib.fix (self: {

  libtorrent_0_13_6 = self."0.13.6";
  libtorrent_0_13_7 = self."0.13.7";
  libtorrent_0_13_8 = self."0.13.8";
  libtorrent_master = self."0.13.8-20230416";

  latest = self.libtorrent_master;

  "0.13.6" = common {
    version = "0.13.6";
    hash = "sha256-lznHPca8nf/VB37CZQg+P7VMTqv/6Wly2laHEdbreec=";

    patches = [
      "${ps.src}/patches/lt-base-cppunit-pkgconfig.patch"
      "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
      "${ps.src}/patches/lt-ps-honor_system_file_allocate_all.patch"
      "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
    ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
  };

  "0.13.7" = common {
    version = "0.13.7";
    hash = "sha256-4E6+N5bHEuDQEZqiesUEeJiC3mXINoQX6LDryLhV+Ag=";

    patches = [
      "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
      ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
      "${ps.src}/patches/lt-ps-log_open_file-reopen_all.patch"
    ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps.src}/patches/lt-open-ssl-1.1.patch";
  };

  "0.13.8" = common {
    version = "0.13.8";
    hash = "sha256-uSDzOU53i0aKm0C27In+zLAAHeKMu5av90DoN5YyvsA=";
    patches = [
      "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
      ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
    ];
  };

  # - ipv6 support
  # - memory crash fixes
  # - udns
  # - scanf crash fix
  "0.13.8-20230416" = (common {
    version = "0.13.8-20230416";
    rev = "91f8cf4b0358d9b4480079ca7798fa7d9aec76b5";
    hash = "sha256-mEIrMwpWMCAA70Qb/UIOg8XTfg71R/2F4kb3QG38duU=";
    patches = [
      "${ps.src}/patches/lt-ps-better-bencode-errors_all.patch"
      ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
      ./patches/libtorrent-udns-0.13.8.patch # from https://github.com/swizzin/swizzin
      ./patches/libtorrent-scanf-0.13.8.patch # from https://github.com/swizzin/swizzin
      ./patches/lookup-cache-0.13.8.patch
    ];
    buildInputs = [ udns ];
  }).override {
    enableAligned = true; # https://github.com/rakshasa/rtorrent/issues/1237
  };
}))
