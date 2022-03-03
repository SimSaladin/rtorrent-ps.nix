{
  description = "rtorrent-ps";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = import ./overlay.nix { };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" ]
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = { inherit (pkgs) rtorrent-ps; };
          defaultPackage = self.packages.${system}.rtorrent-ps;
        }) //
    {
      inherit overlay;
      nixosConfigurations.rtorrent = {
        # TODO
      };
    };
}
