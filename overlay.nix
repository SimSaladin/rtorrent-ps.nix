{ nixpkgs2111 ? null /* pkgsStable: Pinned for dependencies */ }:

let
  versions = import ./rtorrent-ps/versions.nix { };
in

final: prev:

let
  inherit (prev) lib;

  # Python: downgrade to unsupported Python 2 shit to make things work.
  # Pin python packages to stable (python 2 support is very broken in unstable currently)
  pkgsStable =
    if final ? pkgsStable then final.pkgsStable else
    import nixpkgs2111 {
      config = final.config // { allowInsecure = true; }; # XXX borken python deps
      localSystem = final.stdenv.hostPlatform;
    };

  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  pkgsGeneric =
    if final ? pkgsGeneric then final.pkgsGeneric else
    if lib.isGenericSystem final.stdenv.hostPlatform then final else
    import prev.path {
      inherit (final) config;
      localSystem = lib.makeGenericSystem final.stdenv.hostPlatform;
    };

  pyrocore = pkgsStable.callPackage ./pyrocore { inherit lib; };

  rtorrent-magnet = final.callPackage ./rtorrent-magnet { };

  mkPackages = { callPackages, ... }: version: { rev, hash }:
    let
      rtorrent-ps-src = {
        inherit version;
        src = final.fetchFromGitHub {
          owner = "pyroscope";
          repo = "rtorrent-ps";
          inherit rev hash;
        };
      };

    in
    rec {
      rtorrent-ps = rtorrentPSVersions.latest;
      libtorrent = libtorrentVersions.latest;
      rtorrent = rtorrentVersions.latest;

      libtorrentVersions = callPackages ./libtorrent {
        inherit rtorrent-ps-src;
      };

      rtorrentVersions = callPackages ./rtorrent {
        inherit rtorrent-ps-src libtorrentVersions;
      };

      rtorrentPSVersions = callPackages ./rtorrent-ps {
        inherit rtorrent-ps-src rtorrent-magnet pyrocore rtorrentVersions;
      };

      recurseForDerivations = true;
    };

in
{
  rtorrentPSPackages = lib.mapAttrs (mkPackages pkgsGeneric) versions // {
    inherit pyrocore rtorrent-magnet;
    recurseForDerivations = true;
  };
}
