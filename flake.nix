{
  description = "rtorrent-ps";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        overlay = import ./overlay.nix;

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in {
        packages = {
          inherit (pkgs) rtorrent-ps;
        };

        defaultPackage = self.packages.${system}.rtorrent-ps;

        nixosConfigurations.rtorrent = {
          # TODO
        };

        inherit overlay;
      });
}
