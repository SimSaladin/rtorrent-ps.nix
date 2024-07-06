{ config, lib, pkgs, ... }:

# TODO depends on a tmux-server@.service
# TODO depends on a tmux.conf that's not in the repo

let
  inherit (lib) escapeShellArg types mkOption mkIf;

  cfg = config.services.rtorrent-ps;

  progCfg = config.programs.rtorrent-ps;

  tmux_run-shell = cmd:
    "tmux -N2uL ${escapeShellArg cfg.tmuxSocketName} run-shell -C ${escapeShellArg cmd}";

  rtattach = pkgs.writeShellScriptBin "rtattach" ''
    exec tmux -L ${escapeShellArg cfg.tmuxSocketName} attach -t ${escapeShellArg cfg.tmuxSessionName}
  '';
in
{
  options.services.rtorrent-ps = {
    enable = lib.mkEnableOption "rTorrent-PS systemd (user) service";

    package = lib.mkPackageOption pkgs "rtorrent-ps" (
      lib.optionalAttrs progCfg.enable { default = progCfg.finalPackage; }
    );

    tmuxSocketName = mkOption {
      type = types.str;
      default = "rt";
      description = ''
        Tmux socket name (-L option). Default: `rt`.
      '';
    };

    tmuxSessionName = mkOption {
      type = types.str;
      default = "rt";
      description = ''
        Tmux session name (-s option). Default: `rt`.
      '';
    };
  };

  config = mkIf cfg.enable {

    home.packages = [ rtattach ];

    systemd.user.services.rtorrent-ps = {
      Unit = {
        Description = "RTorrent-PS";
        After = [ "network.target" "tmux-server@${cfg.tmuxSocketName}.service" ];
        BindsTo = [ "tmux-server@${cfg.tmuxSocketName}.service" ];
        #RequiresMountsFor = [ "/media/moore" ]; # TODO parameterize
      };
      Service = {
        Type = "oneshot";
        ExecStart = [
          (tmux_run-shell "%hidden RUNRT='${cfg.package}/bin/rtorrent-ps'")
          (tmux_run-shell "source-file #{HOME}/RT/tmux.conf")
        ];
        RemainAfterExit = true;
        LimitFSIZE = "1T";
        LimitRSS = "64G";
        LimitNOFILE = 1048576;
      };
      Install.WantedBy = [ "default.target" ];
    };

    xdg.desktopEntries.rtorrent-attach = {
      name = "Attach to rtorrent tmux session";
      exec = "${rtattach}/bin/rtattach";
      terminal = true;
    };
  };
}
