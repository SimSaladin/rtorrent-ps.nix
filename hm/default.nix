{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.rtorrent-ps;
in
{
  options.programs.rtorrent-ps = {
    enable = mkEnableOption "rTorrent-PS";

    package = mkOption {
      type = types.package;
      default = pkgs.rtorrent-ps;
    };

    finalPackage = mkOption {
      type = types.package;
      visible = false;
      readOnly = true;
    };

    baseDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The rTorrent base directory (RT_HOME).
        Defaults to '~/.rtorrent'.
      '';
    };
  };

  config = mkIf cfg.enable {
      home.packages = [ cfg.finalPackage ];

      programs.rtorrent-ps = {
        # could just set RT_HOME in the session env
        finalPackage = cfg.package.override (optionalAttrs (!builtins.isNull cfg.baseDir) { RT_HOME = cfg.baseDir; });
      };

      xdg.desktopEntries.rtorrent-magnet = {
        name = "rtorrent-magnet";
        exec = "rtorrent-magnet %U";
        mimeType = [ "x-scheme-handler/magnet" ];
        noDisplay = true;
      };

      # Set as default
      xdg.mimeApps.defaultApplications."x-schema-handler/magnet" = [ "rtorrent-magnet.desktop" ];
    };

  imports = [ ./service.nix ];
}
