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
  currentGeneric = import nixpkgs {
    config = final.config;
    system = final.system;
  };

  py2 = nixpkgsStable.python2;

  pyrocore = nixpkgsStable.callPackage ./pyrocore { };
  pyrocoreEnv = py2.buildEnv.override {
    extraLibs = [ pyrocore ];
    ignoreCollisions = true;
  };

  # Sources for patches etc. Just http/git fetch.
  rtorrent-ps-srcs = prev.callPackage ./rtorrent-ps-src.nix { };
  rtorrent-ps-src = rtorrent-ps-srcs.default;

  libtorrents = currentGeneric.callPackage ./libtorrent {
    inherit rtorrent-ps-src;
  };

  rtorrents = currentGeneric.callPackage ./rtorrent {
    inherit rtorrent-ps-src libtorrents;
  };

  rtorrentPSs = currentGeneric.callPackage ./rtorrent-ps {
    inherit rtorrent-ps-src rtorrents pyrocore pyrocoreEnv py2;
  };

in

{
  inherit pyrocore;
  inherit libtorrents rtorrents rtorrentPSs;
}
