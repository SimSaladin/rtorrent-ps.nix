final: prev:

let
  # Sources for patches etc. Just http/git fetch.
  rtorrent-ps-src = (prev.callPackage ./rtorrent-ps-src.nix { }).default;

  pyrocore = final.pkgsStable.callPackage ./pyrocore {
    py2 = final.pkgsStable.python2;
  };

  libtorrents = final.pkgsGeneric.callPackage ./libtorrent {
    inherit rtorrent-ps-src;
  };

  rtorrents = final.pkgsGeneric.callPackage ./rtorrent {
    inherit rtorrent-ps-src libtorrents;
  };

  rtorrentPSs = final.pkgsGeneric.callPackage ./rtorrent-ps {
    inherit rtorrent-ps-src rtorrents pyrocore;
  };

in

{
  inherit pyrocore;
  pyrocoreEnv = pyrocore.pyEnv;
  inherit libtorrents rtorrents rtorrentPSs;
}
