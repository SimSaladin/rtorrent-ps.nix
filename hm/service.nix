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
          # TODO parameterize commands
    systemd.user.services.rtorrent-ps = {
        Unit = {
          Description = "RTorrent-PS";
          After = [ "network.target" "tmux-server@rt.service" ];
          BindsTo = [ "tmux-server@${cfg.tmuxSocketName}.service" ];
          RequiresMountsFor = [ "/media/moore" ]; # TODO parameterize
        };
        Service =
          {
          Type = "oneshot";
          ExecStart =
            let
              RT_EXE = "${cfg.package}/bin/rtorrent-ps";
            in
          [
            ''/usr/bin/tmux -2uv -N -L ${cfg.tmuxSocketName} run-shell -C "%hidden RUNRT='${RT_EXE}'"''
            ''/usr/bin/tmux -2uv -N -L ${cfg.tmuxSocketName} run-shell -C "source-file #{HOME}/RT/tmux.conf"''
          ];
          RemainAfterExit = true;
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
