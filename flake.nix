{
  description = "rtorrent-ps";

  # Default to the latest and greatest (most recent).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  # Except for certain parts that require some really old stuff, use this for
  # those.
  inputs.nixpkgs2111.url = "github:NixOS/nixpkgs/nixos-21.11";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, nixpkgs, nixpkgs2111 }@inputs:
  let
    overlay = import ./overlay.nix inputs;

    homeModule = import ./hm;

    #nixosModule = import ./nixos;
  in
    flake-utils.lib.eachSystem [ "x86_64-linux" ]
      (system:
      let
          pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [ overlay ];
        in
        {
          packages = {
            rtorrent-ps = pkgs.rtorrent-ps.latest;
            inherit (pkgs) pyrocore pyrocoreEnv;
            inherit (pkgs.libtorrents) libtorrent_master;
            inherit (pkgs.rtorrents) rtorrent_master;
            inherit (pkgs.rtorrent-configs) pyroscope rtConfigs rtorrentRc;
          };

          defaultPackage = self.packages.${system}.rtorrent-ps;
        }) //
    {
      overlays.default = overlay;
      hmModules.rtorrent-ps = homeModule;
    };
}
