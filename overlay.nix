{ channels ? { }, ... }:

final: prev:

let
  lib = prev.lib.extend (import ./functions.nix);

  versions = import ./rtorrent-ps/versions.nix { };

  # Python: downgrade to unsupported Python 2 shit to make things work.
  # Pin python packages to stable (python 2 support is very broken in unstable currently)
  pkgs2111 =
    if final ? pkgs2111 then final.pkgs2111
    else channels.${final.system}.nixpkgs2111;

  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  pkgsGeneric =
    if final ? pkgsGeneric then final.pkgsGeneric else
    if lib.isGenericSystem final.stdenv.hostPlatform then final else
    import prev.path {
      inherit (final) config overlays;
      localSystem = lib.makeGenericSystem final.stdenv.hostPlatform;
    };

  mkPackages = scope: version: { rev, hash }:
    lib.makeScope scope.newScope (self:
    lib.recurseIntoAttrs {

      rtorrent-ps-src = {
        inherit version;
        src = final.fetchFromGitHub {
          owner = "pyroscope";
          repo = "rtorrent-ps";
          inherit rev hash;
        };
      };

      rtorrent-ps = self.rtorrentPSPackages.latest;
      libtorrent = self.libtorrentPackages.latest;
      rtorrent = self.rtorrentPackages.latest;

      libtorrentPackages = self.callPackage ./libtorrent { };
      rtorrentPackages = self.callPackage ./rtorrent { };
      rtorrentPSPackages = self.callPackage ./rtorrent-ps { };
    });

  rtorrentPSPackages =
    final.makeScopeWithSplicing' {
      f = self: let
        pyrocorePkgs = self.callPackage ./pyrocore { };
      in
      lib.recurseIntoAttrs {

        defaultVersion = "PS-1.1-71-gee296b1";

        rtorrent-magnet = self.callPackage ./rtorrent-magnet { };

        inherit (pyrocorePkgs)
          pyrocore
          pyrocore-env
          pyrocore-create-imports;
        } // lib.mapAttrs (mkPackages self) versions;

      extra = _: {
        inherit lib pkgs2111 pkgsGeneric;
      };

      otherSplices = { };
    };

in
{
  inherit lib rtorrentPSPackages;
}
