# import args
{ }:

# home-manager module
{ config, lib, pkgs, ... }:

let
  inherit (builtins) isNull;
  inherit (lib) types mkIf mkOption optionalAttrs;

  cfg = config.programs.rtorrent-ps;
in
{
  imports = [
    ./systemd-service.nix
  ];

  options.programs.rtorrent-ps = {
    enable = lib.mkEnableOption "rTorrent-PS";

    package = lib.mkPackageOption pkgs "rtorrent-ps" { };

    baseDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The rTorrent base directory to use. Defaults to `~/.rtorrent` (set to `null`).
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Local rtorrent configuration that gets written to `{baseDir}/_rtlocal.rc`.
      '';
    };

    finalPackage = mkOption {
      type = types.package;
      visible = false;
      readOnly = true;
      description = "The final rtorrent-ps package (read-only).";
    };
  };

  config = mkIf cfg.enable {
      home.packages = [ cfg.finalPackage ];

      home.file."${builtins.replaceStrings ["~/"] [""] cfg.baseDir}/_rtlocal.rc" = {
        enable = cfg.extraConfig != "";
        text = cfg.extraConfig;
      };

      programs.rtorrent-ps = {
        # could just set RT_HOME in the session env
        finalPackage = cfg.package.override (
          optionalAttrs (!isNull cfg.baseDir) { RT_HOME = cfg.baseDir; }
        );
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
}
