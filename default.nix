{ nixpkgs ? import <nixpkgs> { }
, RT_HOME ? null
}@args:

let
  RT_HOME =
    if !builtins.isNull args.RT_HOME then args.RT_HOME
    else if builtins.getEnv "HOME" != "" then builtins.getEnv "HOME" + "/.rtorrent"
    else
      throw ''
        Could not figure out a suitable value for RT_HOME. Pass it as an
        argument or build with --impure.
      '';

  overlay = import ./overlay.nix { inherit RT_HOME; };
in

assert !builtins.isNull (builtins.match "/.+" RT_HOME);

(nixpkgs.extend overlay).rtorrent-ps
