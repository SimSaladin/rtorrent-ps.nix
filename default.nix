{ nixpkgs ? import <nixpkgs> { }
, RT_HOME ? null
}:

let
  overlay = import ./overlay.nix { };
in

(nixpkgs.extend overlay).rtorrent-ps.override { inherit RT_HOME; }
