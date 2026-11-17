{ self
, lib ? self.lib
, pkgs
, pkgsGeneric ? pkgs.pkgsGeneric
,
}:

lib.makeExtensible (
  self':
  lib.recurseIntoAttrs {

    latest = self'.libtorrent_0_16_27;

    libtorrent_0_16_28 = self.callPackage ./package.nix {
      version = "0.16.28";
      hash = "sha256-nRoo5yZQAE4zW7D7DMCg783bVYUGP31uW+GXvbpaiFw=";
      enableAligned = true; # https://github.com/rakshasa/rtorrent/issues/1237
      inherit (pkgsGeneric) stdenv;
    };

    libtorrent_0_16_27 = self.callPackage ./package.nix {
      version = "0.16.27";
      hash = "sha256-m7nQb02VvYneprCW3X5Qg27NWw33DihrKxA7nCjq5DI=";
      enableAligned = true; # https://github.com/rakshasa/rtorrent/issues/1237
      inherit (pkgsGeneric) stdenv;
    };

    #libtorrent_0_13_8 = builder {
    #  version = "0.13.8";
    #  hash = "sha256-uSDzOU53i0aKm0C27In+zLAAHeKMu5av90DoN5YyvsA=";
    #  patches = [
    #    "${ps}/patches/lt-ps-better-bencode-errors_all.patch"
    #    ./patches/lt-ps-honor_system_file_allocate_0.13.7.patch
    #  ];
    #};
  }
)
