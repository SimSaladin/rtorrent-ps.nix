{ lib
, writeTextFile
, pyrocore
}:

let
  inherit (builtins) isNull;

  checkImports = dir: ''
    # check all required imports exist and are readable
    listImports () {
      if [[ $# -gt 0 ]]; then
        mapfile -t res < <(sed -n '/^import\s*=/{s/^import\s*=\s*"\?//; s/"\?\s*$// ;p}' "$@")
        printf '%s\n' "$@"
        listImports "''${res[@]}"
      fi
    }

    mapfile -t imports < <(listImports ${dir})

    for f in "''${imports[@]}"; do
      if [[ -r $f ]]; then
        echo "Imported: $f"
      else
        echo "error: cannot find imported file: $f" >&2
        exit 1
      fi
    done
  '';

  mkImports = lib.concatMapStringsSep "\n" (x@{name ? "", optional ? false, ... }: ''
    # ${name}
    ${if optional then "try_import.if_exists" else "import"
    } = ${getRcFile x}
  '');

  getRcFile = { name ? "rtorrent.rc", source ? null, text ? null, expr ? null, ... }:
    if !isNull source then ''"${source}"''
    else if !isNull text then ''"${builtins.toFile name text}"''
    else if !isNull expr then expr
    else lib.throw "At least one of [source, text, expr] must be defined and not null";

  defaultImports = [
    { name = "helpers"; source = ./helpers.rc; }
    { name = "constants"; source = ./constants.rc; }
    { name = "pyroscope"; text = pyrocore.rtorrentConfigString; }
    { name = "instance-layout"; source = ./instance-layout.rc; }
    { source = ./disable-control-q.rc; }
    { source = ./logging.rc; }
    { source = ./ps-columns.rc; }
    { name = "general settings"; source = ./settings.rc; }
    { source = ./myip.rc; }
    { source = ./network-history.rc; }
    { source = ./watch-disk-space.rc; }
    { source = ./tracker-aliases.rc; }
    { source = ./views.rc; }
    { source = ./watch-dirs.rc; }
    { name = "pyrotorque"; text = ''
        # TORQUE: Daemon watchdog schedule
        # Must be activated by touching the "$RT_HOME/run/pyrotorque" file!
        # Set the second argument of 'pyro.watchdog' to "-v" or "-q" to change
        # log verbosity.
        schedule = pyro_watchdog, 30, 300, ((pyro.watchdog, (cfg.basedir)))
      '';
    }
    { name = "_rtlocal.rc"; expr = ''(cat, (cfg.basedir), "_rtlocal.rc")''; optional = true; }
  ];
in
{
  createRtorrentRC = { files ? [ ], extraConfig ? "" }:
    writeTextFile {
      name = "rtorrent.rc";
      text = ''
        ${mkImports (defaultImports ++ files)}

        # Other additional user settings
        ${extraConfig}
      '';
      checkPhase = checkImports "$out";
    };
}
