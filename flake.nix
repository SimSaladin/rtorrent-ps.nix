{
  description = "rtorrent-ps";

  # Default to the latest and greatest (most recent).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  # Except for certain parts that require some really old stuff, use this for
  # those.
  inputs.nixpkgs2111.url = "github:NixOS/nixpkgs/nixos-21.11";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, nixpkgs, nixpkgs2111 }:
    let
      supportedSystems = [ "x86_64-linux" ];
      overlay' = import ./overlay.nix;
      hmModules.rtorrent-ps = import ./hm;
      #nixosModule = import ./nixos;
    in
    flake-utils.lib.eachSystem supportedSystems
      (system:
        let
          pkgs' = nixpkgs.legacyPackages.${system};

          pkgs = pkgs'.appendOverlays [
            (overlay' { inherit nixpkgs2111; pkgs = pkgs'; })
          ];
        in
        {
          packages = {
            inherit (pkgs) pyrocore;
            inherit (pkgs.rtorrentPSs) rtorrent-ps rtorrent-magnet;
            inherit (pkgs.rtorrentPSs.rtorrent-ps.pkgs) startScript initRc;
            libtorrent = pkgs.libtorrents.libtorrent_master;
            rtorrent = pkgs.rtorrents.rtorrent_master;
            default = self.packages.${system}.rtorrent-ps;
          };

          legacyPackages = with pkgs;
            rtorrents // libtorrents // rtorrentPSs // {
              inherit rtorrents libtorrents rtorrentPSs pyrocore;
            };

          checks = {
            test-rtorrent-ps = self.packages.${system}.rtorrent-ps;
            #test-rtorrent-ps-stable = self.legacyPackages.${system}.rtorrent-ps_stable;
          };
        }
      ) // {
      inherit hmModules;
      overlays.default = overlay' { inherit nixpkgs2111; };

    };
}
