# import args
_:

# home-manager module
{ config, lib, pkgs, ... }:

let
  inherit (builtins) isNull;
  inherit (lib) types mkIf mkOption optionalAttrs;

  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;
in
{
  options = {
    programs.rtorrent-ps = {
      enable = lib.mkEnableOption "rTorrent-PS";

      package = lib.mkPackageOption pkgs "rtorrent-ps" { };

      finalPackage = mkOption {
        type = types.package;
        visible = false;
        readOnly = true;
        description = "The final rtorrent-ps package (read-only).";
      };

      baseDir = mkOption {
        type = types.nullOr types.str;
        default = "${config.home.homeDirectory}/.rtorrent";
        description = ''
          The rTorrent base directory to use.
          Defaults to `~/.rtorrent` (when `null`).
        '';
      };

      settings = mkOption {
        type = types.submodule (import ./rtorrent-options.nix { inherit lib; });
        default = { };
        description = ''
          Local rtorrent configuration that gets written to `{baseDir}/_rtlocal.rc`.
        '';
      };
    };

    services.rtorrent-ps = lib.mkOption {
      type = types.submodule [
        (import ./service-options.nix { inherit pkgs lib; })
        {
          scgiLocal = "${programCfg.baseDir}/.scgi_local";
          tmux.socketPath = "${programCfg.baseDir}/.tmux";
        }
      ];
      default = { };
    };
  };

  config = lib.mkMerge [
    (mkIf programCfg.enable {
      home.packages = [ programCfg.finalPackage ];

      home.file."${builtins.replaceStrings ["${config.home.homeDirectory}/"] [""] programCfg.baseDir}/_rtlocal.rc" = {
        enable = programCfg.settings.content != "";
        text = programCfg.settings.content;
      };

      programs.rtorrent-ps = {
        # could just set RT_HOME in the session env
        finalPackage = programCfg.package.override (
          optionalAttrs (!isNull programCfg.baseDir) { RT_HOME = programCfg.baseDir; } //
          optionalAttrs (!isNull serviceCfg.scgiLocal && serviceCfg.enable) { RT_SOCKET = serviceCfg.scgiLocal; }
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
    })


    (mkIf serviceCfg.enable {
      home.packages = lib.optionals serviceCfg.tmux.enable [ serviceCfg._systemd.rtorrent-attach ];

      systemd.user.services.rtorrent-ps = {
        Unit = {
          Description = "RTorrent-PS";
          After = [ "network.target" ];
          wants = [ "network.target" ];
          #RequiresMountsFor = [ "/media/moore" ]; # TODO parameterize
        };
        Install.WantedBy = [ "default.target" ];
        Service = serviceCfg._systemd.serviceConfig // {
          Environment = {
            PATH = lib.makeSearchPath [
              pkgs.bashInteractive
              pkgs.util-linux
              programCfg.finalPackage
              pkgs.tmux
            ];
            RT_HOME = serviceCfg.stateDir;
            RT_SOCKET = serviceCfg.scgiLocal;
          };
        };
      };
    })
  ];
}
