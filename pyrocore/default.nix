{ lib, python2 /* Must have sufficiently old sphinx */ }:

let
  pyrobase = python2.pkgs.callPackage ./pyrobase.nix { };

  ProxyTypes = python2.pkgs.callPackage ./ProxyTypes.nix { };

  pyrocore = python2.pkgs.callPackage ./pyrocore.nix { inherit lib pyrobase ProxyTypes; };
in
pyrocore
