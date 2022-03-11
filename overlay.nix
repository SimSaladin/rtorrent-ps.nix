{ nixpkgs2111, ... }:

let
  # Pin python packages to stable (python 2 support is very broken in
  # unstable currently)
  python2Packages = nixpkgs2111.python2Packages;
in

final: prev: {
  inherit (final.callPackage ./libtorrent { })
    mkLibtorrent
    libtorrent_0_13_6
    libtorrent_0_13_7
    ;

  libtorrent = final.libtorrent_0_13_6;

  inherit (final.callPackage ./rtorrent { })
    mkRtorrent
    rtorrent_0_9_6
    rtorrent_0_9_7
    ;

  rtorrent = final.rtorrent_0_9_6;
  #rtDebug = final.enableDebugging (final.rtorrent_0_9_7.override { withDebug = true; });

  rtorrent-ps = final.callPackage ./rtorrent-ps { };
  rtorrent-ps_0_9_6 = final.rtorrent-ps;
  rtorrent-ps_0_9_7 = final.rtorrent-ps.override {
    rtorrent = final.rtorrent_0_9_7;
  };

  rtorrent-configs = final.callPackage ./config { };

  pyrocore = final.callPackage ./pyrocore { inherit (python2Packages) buildPythonPackage setuptools six requests prompt_toolkit tempita; };

  pyrobase = final.callPackage ./pyrobase.nix { inherit (python2Packages) buildPythonPackage six tempita; };

  ProxyTypes = final.callPackage ./ProxyTypes.nix { inherit (python2Packages) buildPythonPackage; };

  rtorrentLib.createImport = src: attrs: final.runCommand "create-import" attrs
  ''
    mkdir -p $out
    for f in ${src}/*; do
      substituteAll "$f" $out/"$(basename "$f")"
    done
    ${final.pyrocore}/bin/pyroadmin -q --create-import "$out/*.rc"
  '';
}
