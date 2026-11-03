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

    lib = inputs.nixpkgs.lib;

    nixpkgs2111Config = {
      allowBroken = true;
      permittedInsecurePackages = [
        "python2.7-urllib3-1.26.2"
      ];
    };
  in
    mkFlake {
      inherit self inputs;
      supportedSystems = lib.subtractLists [ "x86_64-darwin" ] defaultSystems;

      debug = true;

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
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          legacyPackages = {
            inherit (pkgs) rtorrentPS;
          };

          packages = flattenTree pkgs.rtorrentPS // {
            default = self.packages.${system}."rtorrent-ps/latest";
          };
        };

      overlays = {
        rtorrent-ps = final: _: {
          rtorrentPS = final.callPackage ./packages.nix { };
          rtorrent-ps = final.rtorrentPS.rtorrent-ps.latest;
        };
        python2-available = _: prev: {
          pkgs2111 = import inputs.nixpkgs2111 {
            inherit (prev.stdenv.hostPlatform) system;
            config = nixpkgs2111Config;
          };
        };
        pkgs-generic = final: prev: {
          # C/C++: Force generic GCC to avoid segfaults with unstable features.
          pkgsGeneric = let
            isGenericSystem = sys:
              (sys.isx86_64 && sys.gcc ? arch) -> sys.gcc.arch == "x86-64" || sys.gcc.arch == "generic";

            makeGenericSystem = sys:
              if sys.isx86_64 then lib.systems.elaborate sys.system else sys;
          in
            prev.pkgsGeneric or
            (if isGenericSystem final.stdenv.hostPlatform then final else
            import prev.path {
              inherit (final) config overlays;
              localSystem = makeGenericSystem final.stdenv.hostPlatform;
            });
        };
        default = lib.composeManyExtensions [
          self.overlays.python2-available
          self.overlays.pkgs-generic
          self.overlays.rtorrent-ps
        ];
      };

      hmModules.default = import ./home-manager { };
    };
}
