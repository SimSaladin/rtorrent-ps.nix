#
# home-manager module for rtorrent-ps setup
#
_:

{ config, lib, pkgs, ... }:

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

      home.file."${builtins.replaceStrings ["${config.home.homeDirectory}/"] [""] programCfg.baseDir}/_rtlocal.rc" = {
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

    (mkIf serviceCfg.enable {

      services.rtorrent-ps = {
        stateDir = "/run/user/${toString config.home.uid}/rtorrent-ps";
        scgiLocal = "/run/user/${toString config.home.uid}/rtorrent-ps/scgi.sock";
        tmux.socketPath = "/run/user/${toString config.home.uid}/rtorrent-ps/tmux.sock";
      };

      home.packages = lib.optionals serviceCfg.tmux.enable [ serviceCfg.nix-support.rtorrent-attach ];

      systemd.user.services.rtorrent-ps = {
        Unit = {
          Description = "RTorrent-PS";
          After = [ "network.target" ];
          Wants = [ "network.target" ];
          X-Restart-Triggers = [ serviceCfg.configFile ];
        };
        Service = lib.mkMerge [
          (serviceCfg.nix-support.serviceConfig // {
            Environment = [
              "PATH=${lib.makeSearchPath "bin" serviceCfg.nix-support.servicePath}"
              "RT_HOME=${serviceCfg.stateDir}"
              "RT_SOCKET=${serviceCfg.scgiLocal}"
              "RT_PIDFILE=%t/rtorrent-ps/rtorrent.pid"
            ];
          })

          (lib.mkIf serviceCfg.tmux.enable {
            InaccessiblePaths = [ "/run/user/${toString config.home.uid}/bus" ];
          })

        ];

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
