{ nixpkgs ? import <nixpkgs> { }
, RT_HOME ? null
}:

let
  overlay = import ./overlay.nix { inherit RT_HOME; };
in

(nixpkgs.extend overlay).rtorrent-ps
