#
# NixOS module for rtorrent-ps setup.
# Setup as a system service and/or application available for all users.
#
{ lib
, pkgs
, config
, ...
}:

let
  inherit (lib) types;
  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;
  inherit (serviceCfg) nix-support;
in

{
  imports = [
    ./program-common-opts.nix
    ./service-options.nix
  ];

  options = {
    programs.rtorrent-ps = {

      system = lib.mkOption {
        type = types.bool;
        default = serviceCfg.enable;
        description = ''
          When true, the default is to work with a system instance
          (`/run/rtorrent-ps/scgi`) instead of a user instance
          (`~/.rtorrent/.scgi_local`).
        '';
      };
    };

    services.rtorrent-ps = {

      user = lib.mkOption {
        type = types.singleLineStr;
        default = "rtorrent-ps";
        description = ''
          Name of the user to run rtorrent-ps as.
        '';
      };
      group = lib.mkOption {
        type = types.singleLineStr;
        default = "rtorrent-ps";
        description = ''
          Group to run rtorrent-ps as.
        '';
      };
      createUser = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to create the user.
        '';
      };
    };
  };

  config = lib.mkIf (programCfg.enable || serviceCfg.enable) {

    services.rtorrent-ps = {
      stateDir = "/var/lib/rtorrent-ps";
      scgiLocal = "/run/rtorrent-ps/scgi";
      tmux.socketPath = "/run/rtorrent-ps/tmux";
    };

    environment.systemPackages =
      lib.optionals programCfg.enable [ programCfg.finalPackage ]
      ++ lib.optionals (serviceCfg.enable && serviceCfg.tmux.enable) [ nix-support.rtorrent-attach ];

    systemd.services = lib.mkIf serviceCfg.enable {
      rtorrent-ps = {
        description = "RTorrent-PS";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        wants = [ "network.target" ];
        restartTriggers = [ serviceCfg.configFile ];
        path = [
          pkgs.bashInteractive
          pkgs.util-linux
          programCfg.finalPackage
        ]
        ++ lib.optional serviceCfg.tmux.enable pkgs.tmux;

        serviceConfig = nix-support.serviceConfig // {
          User = serviceCfg.user;
          Group = serviceCfg.group;
          ProtectHome = true;
          RemoveIPC = true;
        };
        environment = {
          RT_HOME = serviceCfg.stateDir;
          RT_SOCKET = serviceCfg.scgiLocal;
          RT_PIDFILE = "%t/rtorrent-ps/rtorrent.pid";
        };
      };
    };

    systemd.tmpfiles.rules = lib.mkIf serviceCfg.enable [
      "d ${serviceCfg.stateDir} 0750 ${serviceCfg.user} ${serviceCfg.group} -"
    ];

    users = lib.mkIf serviceCfg.enable {
      groups.${serviceCfg.group} = { };
      users.${serviceCfg.user} = lib.mkIf serviceCfg.createUser {
        isSystemUser = true;
        home = serviceCfg.stateDir;
        inherit (serviceCfg) group;
        useDefaultShell = true;
      };
    };
  };
}
