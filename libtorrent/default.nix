{ lib
, callPackage
, pkgsGeneric
, openssl
, udns
, ps
}:
let
  common = args: callPackage ./common.nix ({
    inherit (pkgsGeneric) stdenv;
    inherit ps;
  } // args);
in
lib.recurseIntoAttrs (lib.mapSuffix "PS${ps.version}" (lib.fix (self: {

  "0.13.6" = common {
    version = "0.13.6";
    hash = "sha256-lznHPca8nf/VB37CZQg+P7VMTqv/6Wly2laHEdbreec=";
    patches = [
      "${ps}/patches/lt-base-cppunit-pkgconfig.patch"
      "${ps}/patches/lt-ps-better-bencode-errors_all.patch"
      "${ps}/patches/lt-ps-honor_system_file_allocate_all.patch"
      "${ps}/patches/lt-ps-log_open_file-reopen_all.patch"
    ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps}/patches/lt-open-ssl-1.1.patch";
  };

  "0.13.7" = common {
    version = "0.13.7";
    hash = "sha256-4E6+N5bHEuDQEZqiesUEeJiC3mXINoQX6LDryLhV+Ag=";
    patches = [
      "${ps}/patches/lt-ps-better-bencode-errors_all.patch"
      ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
      "${ps}/patches/lt-ps-log_open_file-reopen_all.patch"
    ] ++ lib.optional (lib.versions.majorMinor openssl.version == "1.1") "${ps}/patches/lt-open-ssl-1.1.patch";
  };

  "0.13.8" = common {
    version = "0.13.8";
    hash = "sha256-uSDzOU53i0aKm0C27In+zLAAHeKMu5av90DoN5YyvsA=";
    patches = [
      "${ps}/patches/lt-ps-better-bencode-errors_all.patch"
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
      "${ps}/patches/lt-ps-better-bencode-errors_all.patch"
      ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
      ./patches/libtorrent-udns-0.13.8.patch # from https://github.com/swizzin/swizzin
      ./patches/libtorrent-scanf-0.13.8.patch # from https://github.com/swizzin/swizzin
      ./patches/lookup-cache-0.13.8.patch
    ];
    buildInputs = [ udns ];
    enableAligned = true; # https://github.com/rakshasa/rtorrent/issues/1237
  });

  "0.16.0-5efa83a" = common {
    version = "0.16.0-5efa83a";
    rev = "5efa83e19aa17a111ae4b9918ffcb330d6496766";
    hash = "sha256-F053OKTcf+mH9Dmo3ZP4SurJs28/MimCnsp2RR1DjWY=";
    patches = [
      ./patches/trackers6.patch
    ];
    postInstall = ''
      for file in tracker/tracker_list.h download/download_main.h data/chunk_handle.h data/chunk_list_node.h download/delegator.h net/address_list.h net/data_buffer.h
      do
        install -Dm0644 $src/src/$file $out/include/$file
      done
      for file in rak/socket_address.h; do
        install -Dm0644 $src/$file $out/include/$file
      done
    '';
  };

  latest = self."0.16.0-5efa83a";
})))
