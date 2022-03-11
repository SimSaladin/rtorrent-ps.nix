{ lib, ... }:

with lib;

let
  program = { config, options, pkgs, ... }:
    let
      cfg = config.programs.rtorrent-ps;
    in
    {
      options.programs.rtorrent-ps = {
        enable = mkEnableOption "rTorrent-PS";

        baseDir = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The rTorrent base directory (RT_HOME).
            Defaults to '~/.rtorrent'.
          '';
        };
      };

      config = mkIf cfg.enable {
        home.packages = [
          # XXX maybe just set RT_HOME in the session env?
          (pkgs.rtorrent-ps.override (
            optionalAttrs (!builtins.isNull cfg.baseDir) { RT_HOME = cfg.baseDir; }))
        ];

        ## TODO
        #rtorrent-magnet = {
        #  name = "rtorrent-magnet";
        #  exec = "rtorrent-magnet %U";
        #  terminal = true;
        #  mimeType = [ "x-scheme-handler/magnet" ];
        #};

        # Set as default
        xdg.mimeApps.defaultApplications."x-schema-handler/magnet" = [ "rtorrent-magnet.desktop" ];
      };
    };

  service = { config, options, ... }:
    let
      cfg = config.services.rtorrent-ps;
    in
    {
      options.services.rtorrent-ps = {
        enable = mkEnableOption "rTorrent-PS";

        tmuxSocketName = mkOption {
          type = types.str;
          default = "rt";
          description = ''tmux socket name (-L option)'';
        };

        config = mkIf cfg.enable {
          # NOTE: attach using: tmux -L rt attach -t rt
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
                "/usr/bin/tmux -L ${cfg.tmuxSocketName} new-session -s rt -n rtorrent -d "
                + "sudo ip netns exec rtorrent su -l sim -c "
                + "rtorrent-ps";
              ExecStop = ''/usr/bin/bash -c "rtxmlrpc quit; while pidof rtorrent >/dev/null; do echo stopping rtorrent...; sleep 1; done"'';
              # TODO implement
              #ExecReload=
              #Restart=on-failure
              LimitFSIZE = "1T";
              LimitRSS = "64G";
              LimitNOFILE = 1048576;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      };
    };
in
{ imports = [ program service ]; }
