{
  description = "rtorrent-ps";

  inputs = {
    # Default to the latest and greatest (most recent).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Except for certain parts that require some really old stuff, use this for
    # those.
    nixpkgs2111.url = "github:NixOS/nixpkgs/nixos-21.11";

    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
  };

  outputs = { self, flake-utils-plus, ... }@inputs:
    let
      inherit (flake-utils-plus.lib) mkFlake defaultSystems flattenTree;

      defaultVersion = "PS-1.1-71-gee296b1";
    in
    mkFlake {
      inherit self inputs;
      supportedSystems = defaultSystems;

      channels.nixpkgs.overlaysBuilder = channels: [
        (_: _: { pkgs2111 = channels.nixpkgs2111; })
        self.overlays.default
      ];

      channels.nixpkgs2111.config = { allowBroken = true; };

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          inherit (pkgs.stdenv.hostPlatform) system;
        in
        {
          packages =
            flattenTree pkgs.rtorrentPSPackages //
            flattenTree pkgs.rtorrentPSPackages.${defaultVersion} //
            { default = self.packages.${system}.rtorrent-ps; };

          checks = {
            test-rtorrent-ps = self.packages.${system}.rtorrent-ps;
          };
        };

      overlays.default = import ./overlay.nix {
        channels = self.pkgs;
      };

      hmModules.default = import ./home-manager { };
    };
}
