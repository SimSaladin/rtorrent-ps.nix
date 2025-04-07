{ channels ? { }, ... }:

final: prev:

let
  lib = prev.lib.extend (import ./functions.nix);

  system = final.stdenv.hostPlatform.system;

  # Python: downgrade to unsupported Python 2 shit to make things work.
  # Pin python packages to stable (python 2 support is very broken in unstable currently)
  pkgs2111 =
    if final ? pkgs2111 then final.pkgs2111
    else channels.${system}.nixpkgs2111;

  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  pkgsGeneric =
    if final ? pkgsGeneric then final.pkgsGeneric else
    if lib.isGenericSystem final.stdenv.hostPlatform then final else
    import prev.path {
      inherit (final) config overlays;
      localSystem = lib.makeGenericSystem final.stdenv.hostPlatform;
    };

  pyrocore = pkgs2111.callPackage ./pyrocore { inherit lib; };

  rtorrent-magnet = final.callPackage ./rtorrent-magnet { };

  versions = import ./rtorrent-ps/versions.nix { };

  mkPackages = version: { rev, hash }:
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
    lib.recurseIntoAttrs rec {
      rtorrent-ps = rtorrentPSPackages.latest;
      libtorrent = libtorrentPackages.latest;
      rtorrent = rtorrentPackages.latest;

      libtorrentPackages = pkgsGeneric.callPackages ./libtorrent {
        inherit rtorrent-ps-src;
      };

      rtorrentPackages = pkgsGeneric.callPackages ./rtorrent {
        inherit rtorrent-ps-src;
        inherit libtorrentPackages;
      };

      rtorrentPSPackages = final.callPackage ./rtorrent-ps {
        inherit rtorrent-ps-src;
        inherit rtorrentPackages;
        inherit rtorrent-magnet pyrocore;
      };
    };

in
{
  inherit lib;

  rtorrentPSPackages = lib.recurseIntoAttrs (lib.mapAttrs mkPackages versions // {
      inherit pyrocore rtorrent-magnet;
  });
}
