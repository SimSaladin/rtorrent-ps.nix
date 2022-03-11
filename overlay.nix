{ nixpkgs2111, ... }:

let
  # Pin python packages to stable (python 2 support is very broken in
  # unstable currently)
  python2Packages = nixpkgs2111.python2Packages;
in

final: prev: {
  inherit (final.callPackage ./libtorrent { }) mkLibtorrent libtorrent_0_13_6 libtorrent_0_13_7 libtorrent_0_13_8 libtorrent_master;

  inherit (final.callPackage ./rtorrent { }) mkRtorrent rtorrent_0_9_6 rtorrent_0_9_7 rtorrent_0_9_8 rtorrent_master;

  rtorrent-ps = {
    "0.9.6" = final.callPackage ./rtorrent-ps {
      rtorrent = final.rtorrent_0_9_6;
      rtorrent-configs = final.callPackage ./config { };
    };
    "0.9.7" = final.rtorrent-ps.stable.override { rtorrent = final.rtorrent_0_9_7; };
    "0.9.8" = final.rtorrent-ps.stable.override { rtorrent = final.rtorrent_0_9_8; };
    "latest" = final.rtorrent-ps.stable.override { rtorrent = final.rtorrent_master; };
    "stable" = final.rtorrent-ps."0.9.6";
  };

  pyrocore = final.callPackage ./pyrocore {
    inherit (python2Packages) buildPythonPackage setuptools six requests prompt_toolkit tempita;
    pyrobase = final.callPackage ./pyrobase.nix { inherit (python2Packages) buildPythonPackage six tempita; };
    ProxyTypes = final.callPackage ./ProxyTypes.nix { inherit (python2Packages) buildPythonPackage; };
  };

  rtorrentLib.createImport = src: attrs: final.runCommand "create-import" attrs
    ''
      mkdir -p $out
      for f in ${src}/*; do
        substituteAll "$f" $out/"$(basename "$f")"
      done
      ${final.pyrocore}/bin/pyroadmin -q --create-import "$out/*.rc"
    '';
}
