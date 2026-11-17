#
# Common module of Nix options for configuring rtorrent as a systemd service
#
{ pkgs
, config
, lib
, ...
}:

let
  inherit (lib) types;

  cfg = config.services.rtorrent-ps;
  rtorrent-ps = config.programs.rtorrent-ps.finalPackage;

  support = {

    servicePath = [
      rtorrent-ps
      pkgs.coreutils
      pkgs.bashInteractive
      pkgs.util-linux
      pkgs.systemdMinimal
      pkgs.curl
      pkgs.dnsutils
    ]
    ++ lib.optional cfg.tmux.enable pkgs.tmux;

    # tmux config created from the service config
    tmuxConfig = pkgs.writeTextFile {
      name = "tmux.conf";
      text = cfg.tmux.settings;
    };

    # run tmux with the preferred flags.
    tmuxRun = "${lib.getExe pkgs.tmux} -2uS ${cfg.tmux.socketPath} -f ${support.tmuxConfig}";

    # For allowing access to other users...
    mkACLs =
      perms:
      lib.concatStringsSep "," (
        lib.map (u: "u:${u}:${perms}") cfg.tmux.allowedUsers
        ++ lib.map (g: "g:${g}:${perms}") cfg.tmux.allowedGroups
      );
    # For allowing access to other users...
    tmuxServerAccess = lib.concatStringsSep "\n" (
      lib.map (u: "server-access -a ${u}") cfg.tmux.allowedUsers
      ++ lib.map (g: "server-access -ag ${g}") cfg.tmux.allowedGroups
    );

    # this is meant to be run by a tmux process that was started as the
    # first service process.
    tmuxServiceStart = pkgs.writeText "rtorrent-tmux.conf" ''
      new-session -dPF '#{session_name} #{socket_path} #{window_index} #{pane_tty}' \
        -s ${cfg.tmux.session} \
        -c ${cfg.stateDir} \
        -e RT_START_EXEC=1 \
        ${lib.getExe' rtorrent-ps "rtorrent-ps"} ${lib.escapeShellArgs cfg.arguments}
      set-window-option remain-on-exit failed
      list-windows -t ${cfg.tmux.session}
      capture-pane -pJ -S -
      ${lib.optionalString (support.tmuxServerAccess != "") ''
        ${support.tmuxServerAccess}
        run-shell -E '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${
          lib.escapeShellArgs [
            (support.mkACLs "rw")
            cfg.tmux.socketPath
          ]
        }
        run-shell -Ebd 1 '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${
          lib.escapeShellArgs [
            (support.mkACLs "rw")
            cfg.scgiLocal
          ]
        }
        run-shell -Ebd 1 '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${
          lib.escapeShellArgs [
            (support.mkACLs "rx")
            cfg.stateDir
          ]
        }
      ''}
      display-message -p -d 1 "Service process launched in tmux window"
      run-shell -E '${lib.getExe' pkgs.systemdMinimal "systemd-notify"} --status="starting up..."'
      list-windows
    '';

    sdNotifyRC = pkgs.writeText "sd-notify.rtorrent.rc" ''
      method.set_key = event.system.startup_done, sd-notify, \
         ((execute.throw, ${lib.getExe' pkgs.systemdMinimal "systemd-notify"}, --ready, --status, "Startup finished", --pid, (system.pid)))
      method.set_key = event.system.shutdown, sd-notify, \
         ((execute.throw, ${lib.getExe' pkgs.systemdMinimal "systemd-notify"}, --stopping, --status, "System shutdown..."))
    '';

    # A convenience executable which can be used to attach the service
    # rtorrent tmux session. To run as a different user than the user of the
    # rtorrent-ps service, you must first allow access for your user. The
    # easiest way to do that is to add your user or group to the allowedUsers
    # or allowedGroups options in this module.
    rtorrent-attach = pkgs.writeShellApplication {
      name = "rtorrent-attach";
      text = ''
        exec ${support.tmuxRun} -N attach -t ${cfg.tmux.session}
      '';
    };

    # Used for journal log plumbing in tmux mode...
    logFIFO = "${cfg.stateDir}/.logfifo";
    # This too
    sdServiceLog = pkgs.writeShellScript "service-log" ''
      exec >>${support.logFIFO}
      if [[ $# -ge 1 ]]; then "$@"; fi
      cat
    '';

    # The script to run as systemd service ExecStart= for the tmux mode.
    tmuxStartScript = pkgs.writeShellScript "rtorrent-ps-start" ''
      set -e
      if [[ -e ${support.logFIFO} ]]; then
        ${lib.getExe' pkgs.coreutils "rm"} ${support.logFIFO}
      fi
      ${lib.getExe' pkgs.coreutils "mkfifo"} ${support.logFIFO}
      coproc { ${lib.getExe' pkgs.coreutils "tail"} -f ${support.logFIFO} | ${lib.getExe' pkgs.util-linux "logger"} -p err; }
      disown %+
      coproc { ${support.tmuxRun} -v -D; }
      disown %+
      sleep 1
      ${support.tmuxRun} -v -N source-file ${support.tmuxServiceStart}
      ${lib.getExe' pkgs.systemdMinimal "systemd-notify"} --status="starting (tmux script finished)..."
      sleep 10
    '';

    # The script to run as systemd service ExecStop= for the tmux mode.
    tmuxStopScript = pkgs.writeShellScript "rtorrent-ps-stop" ''
      rtxmlrpc quit
      echo "Signaled exit, waiting for exit..."
      ${support.tmuxRun} \
         list-windows -t ${cfg.tmux.session} \; \
         wait-for -vE pane-exited \; \
         kill-session -t ${cfg.tmux.session} || :
    '';

    # Common options for both modes (tmux and headless) and also
    # specializations for whichever is active.
    serviceConfig = {
      RuntimeDirectory = "rtorrent-ps";
      ExitType = "cgroup";
      Restart = "on-failure";
      CapabilityBoundingSet = [ ''""'' ];
      NoNewPrivileges = true;
      TimeoutStartSec = 25;

      # NOTE user unit does not work with this on
      #PrivateDevices = true;

      #ProcSubset = "pid";
      #ProtectProc = "invisible";
      PrivateTmp = true;
      MemoryDenyWriteExecute = true;
      ProtectSystem = "full";
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectKernelLogs = true;
      ProtectHostname = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      ProtectClock = true;
      RestrictNamespaces = true;
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      UMask = "0077";
    }
    //

    # Parts for tmux mode only
    lib.optionalAttrs cfg.tmux.enable {
      Type = "notify";
      # prevent creating scope units so that sd-notify can work.
      # XXX: maybe a build of systemd that doesn't use cgroups is better
      # option:
      # <https://github.com/SimSaladin/tmux/commit/ceefb8a57d045961ee3ee8c5b4d1e0d21c48825e>
      #
      # Note that user manager needs to block the user dbus bus as well!
      InaccessiblePaths = [
        "/run/dbus/system_bus_socket"
      ];
      NotifyAccess = "all";
      GuessMainPID = false;
      ExecStart = support.tmuxStartScript;
      ExecStop = support.tmuxStopScript;
      BindLogSockets = true;
    }
    //

    # For daemon (headless) mode only
    lib.optionalAttrs cfg.daemon {
      ExecStart = pkgs.writeShellScript "rtorrent-ps-start" ''
        RT_START_EXEC=1 exec ${lib.getExe' rtorrent-ps "rtorrent-ps"} ${lib.escapeShellArgs cfg.arguments} "$@"
      '';
      KillSignal = "SIGINT";
    };
  };
in
{
  options.services.rtorrent-ps = {

    enable = lib.mkEnableOption "rTorrent-PS";

    daemon = lib.mkEnableOption "Run in daemon mode (without curses UI)";

    arguments = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Command-line arguments used to start rtorrent-ps as a service.
      '';
    };

    settings = lib.mkOption {
      type = types.submodule [ ./rtorrent-options.nix ];
      default = { };
      description = ''
        Additional rtorrent.rc settings.
      '';
    };

    stateDir = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        State directory for rtorrent-ps.
      '';
    };

    scgiLocal = lib.mkOption {
      type = types.path;
      description = ''
        Path to local RPC socket.
      '';
    };

    configFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Additional rtorrent.rc to load.
      '';
    };

    tmux = {
      enable = lib.mkEnableOption "run rtorrent-ps inside tmux" // {
        default = !cfg.daemon;
      };

      socketPath = lib.mkOption {
        type = types.str;
        description = ''
          Path to the tmux server socket.
        '';
      };

      session = lib.mkOption {
        type = types.str;
        default = "rt";
        description = ''
          Tmux session name.
        '';
      };

      settings = lib.mkOption {
        type = types.lines;
        default = "";
        description = ''
          session-wide tmux.conf settigs.
        '';
      };

      allowedUsers = lib.mkOption {
        type = types.listOf types.singleLineStr;
        default = [ ];
        description = ''
          List of users that are allowed to access the tmux server/session.
        '';
      };

      allowedGroups = lib.mkOption {
        type = types.listOf types.singleLineStr;
        default = [ ];
        description = ''
          List of groups that are allowed to access the tmux server/session.
        '';
      };
    };

    nix-support = lib.mkOption {
      type = types.raw;
      internal = true;
      readOnly = true;
    };
  };

  config = lib.mkMerge [

    {
      services.rtorrent-ps = {
        nix-support = support; # XXX
        arguments = lib.mkMerge [
          # Ignore any unmanaged user rtorrent.rc if there happens to be one
          (lib.mkBefore [ "-n" ])
          # Set daemon mode on
          (lib.optionals cfg.daemon [ "-o" "system.daemon.set=1" ])
          # Enable ad-hoc systemd-notify READY=1 for running as a Type=notify service
          (lib.optionals cfg.tmux.enable [
            "-o"
            "import=${support.sdNotifyRC}"
          ])
          # Append service config file if we have one
          (lib.optionals (cfg.configFile != null) [
            "-o"
            "import=${cfg.configFile}"
          ])
        ];
        configFile = lib.mkIf (cfg.settings.generatedConfig != "") (
          pkgs.writeTextFile {
            name = "rtorrent.rc";
            text = cfg.settings.generatedConfig;
          }
        );
        tmux.settings = ''
          set -g exit-empty off
          set -g aggressive-resize on
          set-hook -g command-error {
            run-shell "${support.sdServiceLog} echo #{hook}"
          }
          set-hook -g pane-died {
            run-shell -E "${support.sdServiceLog} echo #{hook}/#{q:hook_pane}:; tmux capture-pane -pJ -t #{q:hook_pane} -S - | ${lib.getExe pkgs.gnused} -z 's/\n\\\s*\n/\n/g' | ${support.sdServiceLog}"
          }
        '';
      };
    }

  ];
}
