{ pkgs, lib }:
let
  inherit (lib) types;

  sdNotifyRC = pkgs.writeText "sd-notify.rtorrent.rc" ''
    method.set_key = event.system.startup_done, sd-notify, \
       ((execute.throw, systemd-notify, --ready, --status, "Startup finished", --pid, (system.pid)))

    method.set_key = event.system.shutdown, sd-notify, \
       ((execute.throw, systemd-notify, --stopping, --status, "System shutdown..."))
  '';

in
{ config, ... }: {
  options = {
    enable = lib.mkEnableOption "rTorrent-PS";
    daemon = lib.mkEnableOption "Run in daemon mode (without curses UI)";
    arguments = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
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
    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/rtorrent-ps";
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
    settings = lib.mkOption {
      type = types.submodule (import ./rtorrent-options.nix { inherit lib; });
      default = { };
      description = ''
        Additional rtorrent.rc settings.
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
      enable = lib.mkEnableOption "run rtorrent-ps inside tmux" // { default = !config.daemon; };
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

      _tmux = lib.mkOption {
        type = types.str;
        internal = true;
        readOnly = true;
      };

      _tmuxStart = lib.mkOption {
        type = types.raw;
        internal = true;
        readOnly = true;
      };
    };

    _systemd = lib.mkOption {
      type = types.raw;
      internal = true;
      readOnly = true;
    };
  };

  config = {
    arguments = lib.mkBefore (
      [ "-n" ] ++
      lib.optionals config.daemon [ "-o" "system.daemon.set=1" ] ++
      lib.optionals config.tmux.enable [ "-o" "import=${sdNotifyRC}" ] ++
      lib.optionals (config.configFile != null) [ "-o" "import=${config.configFile}" ]
    );

    configFile = lib.mkIf (config.settings.content != "") (pkgs.writeTextFile {
      name = "rtorrent.rc";
      text = config.settings.content;
    });

    tmux = {
      settings = ''
        set -g exit-empty off
        set -g aggressive-resize on

        set-hook -g command-error {
          run-shell "${config._systemd.serviceLog} echo #{hook}"
        }
        set-hook -g pane-died {
          run-shell -E "${config._systemd.serviceLog} echo #{hook}/#{q:hook_pane}:; tmux capture-pane -pJ -t #{q:hook_pane} -S - | sed -z 's/\n\\\s*\n/\n/g' | ${config._systemd.serviceLog}"
        }
      '';

      _tmux =
        let
          tmuxConfig = pkgs.writeTextFile {
            name = "tmux.conf";
            text = config.tmux.settings;
          };
        in
        "${lib.getExe pkgs.tmux} -2uS ${config.tmux.socketPath} -f ${tmuxConfig}";

      _tmuxStart =
        let
          mkACLs = perms: lib.concatStringsSep "," (
            lib.map (u: "u:${u}:${perms}") config.tmux.allowedUsers ++
            lib.map (g: "g:${g}:${perms}") config.tmux.allowedGroups
          );

          serverAccess = lib.concatStringsSep "\n" (
            lib.map (u: "server-access -a ${u}") config.tmux.allowedUsers ++
            lib.map (g: "server-access -ag ${g}") config.tmux.allowedGroups
          );
        in
        pkgs.writeText "rtorrent-tmux.conf" ''
          new-session -dPF '#{session_name} #{socket_path} #{window_index} #{pane_tty}' \
            -s ${config.tmux.session} \
            -c ${config.stateDir} \
            rtorrent-ps ${lib.escapeShellArgs config.arguments}
          set-window-option remain-on-exit failed
          list-windows -t ${config.tmux.session}
          capture-pane -pJ -S -

          ${lib.optionalString (serverAccess != "") ''
            ${serverAccess}
            run-shell -E '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${lib.escapeShellArgs [ (mkACLs "rw") config.tmux.socketPath ]}
            run-shell -Ebd 1 '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${lib.escapeShellArgs [ (mkACLs "rw") config.scgiLocal ]}
            run-shell -Ebd 1 '${pkgs.acl}/bin/setfacl -m #{q:1} #{q:2}' ${lib.escapeShellArgs [ (mkACLs "rx") config.stateDir ]}
          ''}
        '';
    };


    _systemd = {
      rtorrent-attach = pkgs.writeShellApplication {
        name = "rtorrent-attach";
        text = ''
          exec ${config.tmux._tmux} -N attach -t ${config.tmux.session}
        '';
      };
      logFIFO = "${config.stateDir}/.logfifo";
      serviceLog = pkgs.writeShellScript "service-log" ''
        exec >>${config._systemd.logFIFO}
        if [[ $# -ge 1 ]]; then "$@"; fi
        cat
      '';
      serviceConfig =
        lib.optionalAttrs config.tmux.enable
          {
            Type = "notify";
            NotifyAccess = "all";
            GuessMainPID = false;
            ExecStart = pkgs.writeShellScript "rtorrent-ps-start" ''
              if [[ -e ${config._systemd.logFIFO} ]]; then
                rm ${config._systemd.logFIFO}
              fi
              mkfifo ${config._systemd.logFIFO}
              coproc { tail -f ${config._systemd.logFIFO} | logger -p err; }
              coproc { ${config.tmux._tmux} -D; }
              sleep 1
              ${config.tmux._tmux} -N source-file ${config.tmux._tmuxStart}
            '';
            ExecStop = pkgs.writeShellScript "rtorrent-ps-stop" ''
              rtxmlrpc quit
              ${config.tmux._tmux} \
                 list-windows -t ${config.tmux.session} \; \
                 wait-for -vE pane-exited \; \
                 kill-session -t ${config.tmux.session} || :
            '';
            BindLogSockets = true;
          }
        //
        lib.optionalAttrs config.daemon {
          ExecStart = pkgs.writeShellScript "rtorrent-ps-start" ''
            RT_START_EXEC=1 exec rtorrent-ps ${lib.escapeShellArgs config.arguments} "$@"
          '';
          KillSignal = "SIGINT";
        };
    };
  };
}
