{ lib
, pkgs
, config
, ...
}:

let
  inherit (lib) types;

  programCfg = config.programs.rtorrent-ps;
  serviceCfg = config.services.rtorrent-ps;

in

{
  options = {
    programs.rtorrent-ps = {
      enable = lib.mkEnableOption "rTorrent-PS";

      package = lib.mkPackageOption pkgs "rtorrent-ps" { };

      finalPackage = lib.mkOption {
        type = types.package;
        visible = false;
        readOnly = true;
        description = "The final rtorrent-ps package (read-only).";
      };

      baseDir = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The rTorrent base directory to use.
          Defaults to `~/.rtorrent` (when `null`).
        '';
      };

      workDir = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Override RT_DOWNLOAD_PATH
        '';
      };
    };
  };

  config.programs.rtorrent-ps = {
    # could just set RT_HOME in the session env
    finalPackage = programCfg.package.override (
      lib.optionalAttrs (!isNull programCfg.baseDir) { RT_HOME = programCfg.baseDir; }
      // lib.optionalAttrs (!isNull programCfg.workDir) { RT_DOWNLOAD_PATH = programCfg.workDir; }
      // lib.optionalAttrs (!isNull serviceCfg.scgiLocal && serviceCfg.enable) {
        RT_SOCKET = serviceCfg.scgiLocal;
      }
    );
  };
}
