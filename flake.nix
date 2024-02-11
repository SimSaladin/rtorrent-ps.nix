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
      overlays.default = import ./overlay.nix;
      hmModules.rtorrent-ps = import ./hm;
      #nixosModule = import ./nixos;
    in
    flake-utils.lib.eachSystem supportedSystems
      (system:
        let
          pkgs' = nixpkgs.legacyPackages.${system};

          # Python: downgrade to unsupported Python 2 shit to make things work.
          # Pin python packages to stable (python 2 support is very broken in unstable currently)
          pkgsStable = import nixpkgs2111 {
            config = pkgs'.config // { allowInsecure = true; }; # XXX borken python deps
            localSystem = pkgs'.hostPlatform;
          };

          # C/C++: Force generic GCC to avoid segfaults with unstable features.
          pkgsGeneric = import nixpkgs {
            config = pkgs'.config;
            inherit system;
          };

          pkgs = pkgs'.appendOverlays [
            overlays.default
            (_: _: { inherit pkgsStable pkgsGeneric; })
          ];
        in
        {
          packages = {
            inherit (pkgs) pyrocore pyrocoreEnv;
            inherit (pkgs.libtorrents) libtorrent_master;
            inherit (pkgs.rtorrents) rtorrent_master;
            inherit (pkgs.rtorrentPSs) rtorrent-ps rtorrent-magnet;
            inherit (pkgs.rtorrentPSs.rtorrent-ps.pkgs) startScript initRc;
            default = self.packages.${system}.rtorrent-ps;
          };

          legacyPackages = with pkgs;
            rtorrents // libtorrents // rtorrentPSs;

          checks = {
            test-rtorrent-ps = self.packages.${system}.rtorrent-ps;
            #test-rtorrent-ps-stable = self.legacyPackages.${system}.rtorrent-ps_stable;
          };
        }
      ) // { inherit overlays hmModules; };
}
