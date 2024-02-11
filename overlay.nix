# Pinned pkgs
{ nixpkgs2111
  # Generic
, pkgs ? null
, ...
}:

final: prev:

let

  # Python: downgrade to unsupported Python 2 shit to make things work.
  # Pin python packages to stable (python 2 support is very broken in unstable currently)
  pkgsStable = if prev ? pkgsStable then prev.pkgsStable else
  import nixpkgs2111 {
    config = prev.config // { allowInsecure = true; }; # XXX borken python deps
    localSystem = prev.hostPlatform;
  };


  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  pkgsGeneric = if prev ? pkgsGeneric then prev.pkgsGeneric else
  if pkgs != null then pkgs else
  import prev.path {
    config = final.config;
    system = final.hostPlatform.system;
    #localSystem = prev.lib.systems.elaborate (prev.stdenv.system);
  };

in


let
  # Sources for patches etc. Just http/git fetch.
  rtorrent-ps-src = (prev.callPackage ./rtorrent-ps-src.nix { }).default;

  pyrocore = pkgsStable.callPackage ./pyrocore {
    py2 = pkgsStable.python2;
  };

  libtorrents = pkgsGeneric.callPackage ./libtorrent {
    inherit rtorrent-ps-src;
  };

  rtorrents = pkgsGeneric.callPackage ./rtorrent {
    inherit rtorrent-ps-src libtorrents;
  };

  rtorrentPSs = pkgsGeneric.callPackage ./rtorrent-ps {
    inherit rtorrent-ps-src rtorrents pyrocore;
  };

in

{
  inherit pyrocore libtorrents rtorrents rtorrentPSs;
} // libtorrents // rtorrents // rtorrentPSs
