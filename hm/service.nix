{ config, options, lib, pkgs, ... }:

with lib;

let
  rtCfg = config.programs.rtorrent-ps;
  cfg = config.services.rtorrent-ps;

  rtattach = pkgs.writeShellScriptBin "rtattach" ''
    exec tmux -L ${cfg.tmuxSocketName} attach -t rt
  '';
in
{
  options.services.rtorrent-ps = {
    enable = mkEnableOption "rTorrent-PS";

    package = mkOption {
      type = types.package;
      default = if rtCfg.enable then rtCfg.finalPackage else pkgs.rtorrent-ps;
    };

    tmuxSocketName = mkOption {
      type = types.str;
      default = "rt";
      description = ''tmux socket name (-L option)'';
    };

    tmuxSessionName = mkOption {
      type = types.str;
      default = "rt";
      description = ''tmux session name (-s option)'';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.rtorrent-ps = {
        Unit = {
          Description = "RTorrent-PS";
          After = [ "network.target" ];
          RequiresMountsFor = [ "/media/moore" ]; # TODO parameterize
        };
        Service = {
          Type = "forking";

          # TODO parameterize commands
          ExecStart =
            let
              netns = "rtorrent";
              user = "sim";
              rtCmd = "sudo ip netns exec ${netns} su -l ${user} -c ${cfg.package}/bin/rtorrent-ps";
              newSession = "new-session -s ${cfg.tmuxSessionName} -d -P ${rtCmd}";
              setOption = "set-option -s exit-empty on";
            in
            "/usr/bin/tmux -L ${cfg.tmuxSocketName} ${newSession} \\; ${setOption}";

          ExecStop =
            let
              quitRpc = "${cfg.package}/bin/rtxmlrpc quit";
              wait = "while pidof rtorrent >/dev/null; do echo stopping rtorrent...; sleep 1; done";
            in
            ''/usr/bin/bash -c "if ${quitRpc}; then; ${wait}; fi; exit 0"'';

          LimitFSIZE = "1T";
          LimitRSS = "64G";
          LimitNOFILE = 1048576;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
    };

    home.packages = [ rtattach ];

    xdg.desktopEntries.rtorrent-attach = {
      name = "Attach to rtorrent tmux session";
      exec = "${rtattach}/bin/rtattach";
      terminal = true;
    };
  };
}
