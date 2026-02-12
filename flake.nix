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

  outputs = { self, flake-utils-plus, ... }@inputs: let
    inherit (flake-utils-plus.lib) mkFlake defaultSystems flattenTree;

    nixpkgs2111Config = {
      allowBroken = true;
      permittedInsecurePackages = [
        "python2.7-urllib3-1.26.2"
      ];
    };
  in
    mkFlake {
      inherit self inputs;
      supportedSystems = defaultSystems;

      channels.nixpkgs.overlaysBuilder = channels: [
        (_: _: { pkgs2111 = channels.nixpkgs2111; })
        self.overlays.default
      ];

      # Python: downgrade to unsupported Python 2 shit to make things work.
      # Pin python packages to stable (python 2 support is very broken in unstable currently)
      channels.nixpkgs2111.config = nixpkgs2111Config;

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          #inherit (pkgs.stdenv.hostPlatform) system;
        in
        {
          legacyPackages = { inherit (pkgs.rtorrentPS) pyrocore; };

          packages =
            flattenTree pkgs.rtorrentPS
            #// { default = self.packages.${system}.rtorrent-ps; }
            ;

          checks = {
            #test-rtorrent-ps = self.packages.${system}.rtorrent-ps;
          };
        };

      overlays.default = import ./overlay.nix {
        nixpkgs2111 = import inputs.nixpkgs2111 {
          system = "x86_64-linux"; # XXX
          config = nixpkgs2111Config;
        };
      };

      hmModules.default = import ./home-manager { };
    };
}
