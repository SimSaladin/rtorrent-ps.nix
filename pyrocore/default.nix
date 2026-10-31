{ lib ? pkgs.lib
, pkgs
, pkgs2111 ? pkgs.pkgs2111
}:

let
  inherit (pkgs2111) python2; /* Must have sufficiently old sphinx */

  # callPackage so that missing python2 pkgs are taken from old pkgset,
  # while everything else is from the default pkgset.
  callOldPythonPackage = lib.callPackageWith (pkgs // python2.pkgs // {
    inherit python2; });

  pyrobase = callOldPythonPackage ./pyrobase.nix { };

  ProxyTypes = callOldPythonPackage ./ProxyTypes.nix { };

  pyrocore = callOldPythonPackage ./pyrocore.nix {
    inherit pyrobase ProxyTypes;
  };
in
  pyrocore
