_:

{ lib, pkgs, config, ... }:

let
  inherit (lib) types;
  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;
in

{
  options = {
    programs.rtorrent-ps = {
      enable = lib.mkEnableOption "rTorrent-PS";

      system = lib.mkOption {
        type = types.bool;
        default = serviceCfg.enable;
        description = ''
          When true, the default is to work with a system instance
          (`/run/rtorrent-ps/scgi`) instead of a user instance
          (`~/.rtorrent/.scgi_local`).
        '';
      };

      package = lib.mkPackageOption pkgs "rtorrent-ps" { };

      finalPackage = lib.mkOption {
        type = types.package;
        visible = false;
        readOnly = true;
        description = "The final rtorrent-ps package (read-only).";
      };
    };

    services.rtorrent-ps = lib.mkOption {
      type = types.submodule [
        (import ./service-options.nix { inherit pkgs lib; })
        {
          scgiLocal = "/run/rtorrent-ps/scgi";
          tmux.socketPath = "/run/rtorrent-ps/tmux";
        }
      ];
      default = { };
    };
  };

  config = lib.mkIf (programCfg.enable || serviceCfg.enable) {

    environment.systemPackages =
      lib.optionals programCfg.enable [ programCfg.finalPackage ] ++
      lib.optionals (serviceCfg.enable && serviceCfg.tmux.enable) [ serviceCfg._systemd.rtorrent-attach ]
    ;

    programs.rtorrent-ps = {
      finalPackage = programCfg.package.override (
        lib.optionalAttrs programCfg.system {
          RT_SOCKET = serviceCfg.scgiLocal;
        }
      );
    };

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
        serviceConfig = serviceCfg._systemd.serviceConfig //
          {
            RuntimeDirectory = "rtorrent-ps";
            User = serviceCfg.user;
            Group = serviceCfg.group;
            ExitType = "cgroup";
            Restart = "on-failure";
            CapabilityBoundingSet = [ ''""'' ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "full";
            ProtectHome = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectKernelLogs = true;
            ProtectHostname = true;
            ProtectProc = "invisible";
            UMask = "0077";
            RemoveIPC = true;
            ProtectClock = true;
            RestrictNamespaces = true;
            SystemCallArchitectures = "native";
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            MemoryDenyWriteExecute = true;
            ProcSubset = "pid";
            LockPersonality = true;
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];
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
