{ nixpkgs, nixpkgs2111, ... }:

final: prev:

let
  # Python: downgrade to unsupported Python 2 shit to make things work.
  # Pin python packages to stable (python 2 support is very broken in unstable currently)
  nixpkgsStable = import nixpkgs2111 {
    config = final.config // { allowInsecure = true; }; # XXX borken python deps
    localSystem = final.hostPlatform;
  };

  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  currentGeneric = import final {
    config = final.config;
    system = final.system;
  };

  pyrocore = nixpkgsStable.callPackage ./pyrocore { };

  # Sources for patches etc. Just http/git fetch.
  rtorrent-ps-srcs = (prev.callPackage ./rtorrent-ps-src.nix { }).latest;

  libtorrents = currentGeneric.callPackage ./libtorrent { inherit rtorrent-ps-srcs; };

  rtorrents = currentGeneric.callPackage ./rtorrent { inherit rtorrent-ps-srcs libtorrents; };

  rtorrentPS = args: final.callPackage ./rtorrent-ps ({
    src = rtorrent-ps-srcs.default;
    py2 = nixpkgsStable.python2;
  } // args);

in

{
  inherit libtorrents rtorrents pyrocore;

  rtorrent-ps = with rtorrents; {
    "0.9.6" = rtorrentPS { rtorrent = rtorrent_0_9_6; };
    "0.9.7" = rtorrentPS { rtorrent = rtorrent_0_9_7; };
    "0.9.8" = rtorrentPS { rtorrent = rtorrent_0_9_8; };
    "latest" = rtorrentPS { rtorrent = rtorrent_master; };
    "stable" = final.rtorrent-ps."0.9.6";
  };
}
