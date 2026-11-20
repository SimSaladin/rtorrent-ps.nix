#
# home-manager module for rtorrent-ps setup
#
{ config, lib, ... }:

let
  inherit (lib) types mkIf mkOption;

  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;
in
{
  imports = [
    ./program-common-opts.nix
    ./service-options.nix
  ];

  options = {
    programs.rtorrent-ps = {
      settings = mkOption {
        type = types.submodule [ ./rtorrent-options.nix ];
        default = { };
        description = ''
          Local rtorrent configuration that gets written to `{baseDir}/_rtlocal.rc`.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (mkIf programCfg.enable {

      programs.rtorrent-ps = {
        baseDir = "${config.home.homeDirectory}/.rtorrent";
      };

      home.packages = [ programCfg.finalPackage ];

      home.file."${
        builtins.replaceStrings [ "${config.home.homeDirectory}/" ] [ "" ] programCfg.baseDir
      }/_rtlocal.rc" =
        {
          enable = programCfg.settings.generatedConfig != "";
          text = programCfg.settings.generatedConfig;
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

    (
      # XXX why these needed when not even enabling the service??
      mkIf (!serviceCfg.enable) {
        services.rtorrent-ps = {
          scgiLocal = "/run/user/${toString config.home.uid}/rtorrent-ps/scgi.sock";
        };
      }
    )

    (mkIf serviceCfg.enable {

      home.packages = lib.optional serviceCfg.tmux.enable serviceCfg.nix-support.rtorrent-attach;

      services.rtorrent-ps = {
        stateDir = "/run/user/${toString config.home.uid}/rtorrent-ps";
        scgiLocal = "/run/user/${toString config.home.uid}/rtorrent-ps/scgi.sock";
        tmux.socketPath = "/run/user/${toString config.home.uid}/rtorrent-ps/tmux.sock";
      };

      systemd.user.sockets = lib.mkIf serviceCfg.enableSocketActivation {
        rtorrent-ps = {
          Socket = {
            ListenStreams = [ serviceCfg.scgiLocal ];
          };
          Install.WantedBy = [ "sockets.target" ];
        };
      };

      systemd.user.services.rtorrent-ps = {
        Unit = {
          Description = "RTorrent-PS";
          After = [ "network.target" ];
          Wants = [ "network.target" ];
          X-Restart-Triggers = [ serviceCfg.configFile ];
          Requires = lib.optional serviceCfg.enableSocketActivation "rtorrent-ps.socket";
        };
        Service = lib.mkMerge [
          (
            serviceCfg.nix-support.serviceConfig
              // {
              Environment = lib.mapAttrsToList (k: v: "${k}=${v}") serviceCfg.environment;
            }
          )

          (lib.mkIf serviceCfg.tmux.enable {
            InaccessiblePaths = [ "/run/user/${toString config.home.uid}/bus" ];
          })

        ];
      }
      // lib.optionalAttrs (!serviceCfg.enableSocketActivation) {
        Install.WantedBy = [ "default.target" ];
      }
      ;
    })
  ];
}
