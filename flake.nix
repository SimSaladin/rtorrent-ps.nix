{
  description = "rtorrent-ps";

  inputs = {
    # Default to the latest and greatest (most recent).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Except for certain parts that require some really old stuff, use this for
    # those.
    nixpkgs2111.url = "github:NixOS/nixpkgs/nixos-21.11";

    flutils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  };

  outputs = { self, flutils, ... }@inputs:
    let
      inherit (flutils.lib) flattenTree;

      defaultVersion = "PS-1.1-71-gee296b1";
    in
    flutils.lib.mkFlake {
      inherit self inputs;

      supportedSystems = flutils.lib.defaultSystems;

      channels.nixpkgs.overlaysBuilder = _channels: [ self.overlays.default ];

      channels.nixpkgs2111.config = { allowBroken = true; };

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          inherit (pkgs.stdenv.hostPlatform) system;
          packages = pkgs.rtorrentPSPackages;
          defaultPackages = packages.${defaultVersion};
        in
        {
          packages = flattenTree packages // flattenTree defaultPackages // {
            default = self.packages.${system}.rtorrent-ps;
          };

          checks = {
            test-rtorrent-ps = self.packages.${system}.rtorrent-ps;
          };
        };

      hmModules.default = import ./home-manager { };

      overlays.default = import ./overlay.nix { channels = self.pkgs; };
    };
}
