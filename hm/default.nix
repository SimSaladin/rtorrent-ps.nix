{ options, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.rtorrent-ps;

in {
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
      (pkgs.rtorrent-ps.override { RT_HOME = cfg.baseDir; })
    ];
  };
}
