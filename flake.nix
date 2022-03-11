{
  description = "rtorrent-ps";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs2111.url = "github:NixOS/nixpkgs/nixos-21.11";

  outputs = { self, nixpkgs, flake-utils, nixpkgs2111 }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ]
      (system:
        let
          overlay = import ./overlay.nix { nixpkgs2111 = import nixpkgs2111 { inherit system; }; };
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            inherit (pkgs)
            libtorrent
            libtorrent_0_13_6
            libtorrent_0_13_7
            libtorrent_0_13_8
            rtorrent
            rtorrent_0_9_6
            rtorrent_0_9_7
            rtorrent_0_9_8
            rtorrent-ps
            rtorrent-ps_0_9_7
            rtorrent-ps_0_9_8
            pyrocore
            pyrobase;
          };
          defaultPackage = self.packages.${system}.rtorrent-ps;
        }) //
    {
      overlay = import ./overlay.nix { nixpkgs2111 = import nixpkgs2111 { }; };

      #nixosModules.rtorrent-ps = import ./nixos;
      #nixosModule = self.nixosModules.home-manager;

      homeModules.rtorrent-ps = import ./hm;
      homeModule = self.homeModules.rtorrent-ps;
    };
}
