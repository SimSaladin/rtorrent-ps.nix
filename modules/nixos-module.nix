_:

{ lib, pkgs, config, ... }:

let
  inherit (lib) types;
  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;

  runtimeDir = "/run/rtorrent-ps";
  logFIFO = "${serviceCfg.stateDir}/.logfifo";

  tmuxExe = "${lib.getExe pkgs.tmux} -S ${serviceCfg.tmux.socketPath} -2u -f ${tmuxConfig}";

  tmuxConfig = pkgs.writeTextFile {
    name = "tmux.conf";
    text = ''
      set -g exit-empty off
      set -g aggressive-resize on

      set-hook -g command-error "run-shell \"echo >>${logFIFO} '#{hook}'\""
      set-hook -g pane-died "run-shell \"exec >${logFIFO}; echo '#{hook}: #T:'; tmux capture-pane -pJ -t #D -S - | sed -z 's/\n\s*\n/\n/'\""
    '';
  };

  rtorrent-attach = pkgs.writeShellApplication {
    name = "rtorrent-attach";
    text = ''
      if [[ $(id --name -u) == ${serviceCfg.user} ]]; then
        ${tmuxExe} -N attach -t ${serviceCfg.tmux.session}
      elif [[ $(id -u) == 0 ]]; then
        su ${serviceCfg.user} -c "${tmuxExe} -N attach -t ${serviceCfg.tmux.session}"
      else
        sudo -u ${serviceCfg.user} ${tmuxExe} -N attach -t ${serviceCfg.tmux.session}
      fi
    '';
  };

  defaultServiceConf = pkgs.writeText "rtorrent.rc" ''
    method.set_key = event.system.startup_done, sd-notify, \
       ((execute.throw, systemd-notify, --ready, --status, "Startup finished", --pid, (system.pid)))

    method.set_key = event.system.shutdown, sd-notify, \
       ((execute.throw, systemd-notify, --stopping, --status, "System shutdown..."))
  '';
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

    services.rtorrent-ps = {
      enable = lib.mkEnableOption "rTorrent-PS";
      user = lib.mkOption {
        type = types.str;
        default = "rtorrent-ps";
      };
      group = lib.mkOption {
        type = types.str;
        default = "rtorrent-ps";
      };
      stateDir = lib.mkOption {
        type = types.str;
        default = "/var/lib/rtorrent-ps";
      };
      scgiLocal = lib.mkOption {
        type = types.str;
        default = "${runtimeDir}/scgi";
      };
      configFile = lib.mkOption {
        type = types.path;
        default = defaultServiceConf;
      };

      tmux.socketPath = lib.mkOption {
        type = types.str;
        default = "${runtimeDir}/tmux";
      };
      tmux.session = lib.mkOption {
        type = types.str;
        default = "rt";
      };
    };
  };

  config = lib.mkIf (programCfg.enable || serviceCfg.enable) {
    programs.rtorrent-ps = {

      finalPackage = programCfg.package.override (
        if programCfg.system then {
          RT_SOCKET = "${runtimeDir}/scgi";
        } else { }
        );
        #cfg.package.override ( lib.optionalAttrs (!isNull cfg.baseDir) { RT_HOME = cfg.baseDir; });
    };

    environment.systemPackages =
      lib.optionals programCfg.enable [ programCfg.finalPackage ] ++
      lib.optionals serviceCfg.enable [ rtorrent-attach ]
      ;

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
          pkgs.tmux
          programCfg.finalPackage
        ];
        preStart = ''
          if [[ -e ${logFIFO} ]]; then
            rm ${logFIFO}
          fi
          mkfifo ${logFIFO}
        '';
        script = ''
          export RT_START_EXEC=1
          export RT_PIDFILE=''${RT_PIDFILE:-$RUNTIME_DIRECTORY/rtorrent.pid}
          coproc {
             tail -f ${logFIFO} | logger -p err
          }
          disown %+
          coproc {
            sleep 1
            ${tmuxExe} -N \
               new-session -dP -s ${serviceCfg.tmux.session} \
                   -c ${serviceCfg.stateDir} \
                   -n rtorrent-ps \
                   rtorrent-ps -o "import=${serviceCfg.configFile}" \; \
               set-window-option remain-on-exit failed \; \
               list-windows -t ${serviceCfg.tmux.session} \; \
               capture-pane -peJ -S -
            systemd-notify --status="Forked rtorrent-ps inside tmux..."
          }
          disown %+
          exec ${tmuxExe} -D
        '';
        serviceConfig = {
          RuntimeDirectory = "rtorrent-ps";
          Type = "notify";
          NotifyAccess = "all";
          User = serviceCfg.user;
          Group = serviceCfg.group;
          ExitType = "cgroup";
          GuessMainPID = false;
          #PIDFile = "${runtimeDir}/rtorrent.pid";
          ExecStop = pkgs.writeShellScript "rtorren-ps-stop" ''
            rtxmlrpc quit
            ${tmuxExe} \
               list-windows -t ${serviceCfg.tmux.session} \; \
               wait-for -vE pane-exited \; \
               kill-session -t ${serviceCfg.tmux.session} || :
          '';

          Restart = "on-failure";
          BindLogSockets = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          MemoryDenyWriteExecute = true;
          LockPersonality = true;
        };
        environment = {
          RT_HOME = serviceCfg.stateDir;
          RT_SOCKET = serviceCfg.scgiLocal;
        };
      };
    };

    systemd.tmpfiles.rules = lib.mkIf serviceCfg.enable [
      "d ${serviceCfg.stateDir} 0750 ${serviceCfg.user} ${serviceCfg.group} -"
    ];

    users = lib.mkIf serviceCfg.enable {
      groups.${serviceCfg.group} = { };
      users.${serviceCfg.user} = {
        isSystemUser = true;
        home = serviceCfg.stateDir;
        inherit (serviceCfg) group;
        useDefaultShell = true;
      };
    };
  };
}
