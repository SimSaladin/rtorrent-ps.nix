{ lib
, callPackage
, makeScopeWithSplicing'
, sources ? callPackage ./sources.nix { }
}:

let
  packages = self:
    let
      mkPackages = src:
        lib.makeScope self.newScope (self: {
          libtorrentPackages = self.callPackage ./libtorrent {
            ps = src;
          };
          rtorrentPackages = self.callPackage ./rtorrent {
            ps = src;
          };
          rtorrentPSPackages = self.callPackage ./rtorrent-ps {
            ps = src;
          };
        });
    in
    lib.recurseIntoAttrs {
        inherit sources;

        defaultVersion = sources.defaults.rtorrent-ps;

        pyrocore = self.callPackage ./pyrocore { };

        rtorrent-magnet = self.callPackage ./rtorrent-magnet { };

        rtorrent-config = self.callPackage ./rtorrent-config { };

        rtorrent-ps = self.rtorrentPSPackages.${lib.versionToName "latest/PS${sources.defaults.rtorrent-ps}"};

      } // lib.fold lib.recursiveUpdate { } (lib.map mkPackages sources.rtorrent-ps);
in
makeScopeWithSplicing' {
  f = packages;
  otherSplices = { };
}
