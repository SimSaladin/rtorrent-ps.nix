{ lib
#, runCommand
#, replaceVarsWith
, writeTextFile
, pyrocore
}:

let
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

  getRcFile = attrs:
  if !builtins.isNull (attrs.source or null) then ''"${attrs.source}"''
  else if !builtins.isNull (attrs.text or null) then ''"${builtins.toFile (attrs.name or "rtorrent.rc") attrs.text}"''
  else if !builtins.isNull (attrs.expr or null) then attrs.expr
  else lib.throw "At least one of [source, text, expr] must be defined and not null";

  defaults = [
    { name = "helpers"; source = ./helpers.rc; }
    { name = "constants"; source = ./constants.rc; }
    { name = "rtpyro"; text = ''
        # Set this to '0' to prevent logging of existing key bindings being replaced
        branch=(pyro.extended), ((ui.bind_key.verbose.set, 0))

        ${pyrocore.rtorrentConfigString}

        # TORQUE: Daemon watchdog schedule
        # Must be activated by touching the "$RT_HOME/run/pyrotorque" file!
        # Set the second argument of 'pyro.watchdog' to "-v" or "-q" to change
        # log verbosity.
        schedule = pyro_watchdog, 30, 300, ((pyro.watchdog, (cfg.basedir)))
      ''; }

    { source = ./disable-control-q.rc; }
    { name = "instance-layout"; source = ./instance-layout.rc; }
    { source = ./ps-columns.rc; }
    { name = "general settings"; source = ./settings.rc; }
    { source = ./logging.rc; }
    { source = ./network-history.rc; }
    { source = ./watch-disk-space.rc; }
    { source = ./tracker-aliases.rc; }
    { source = ./views.rc; }
    { source = ./watch-dirs.rc; }
  ];
in
{
  createRtorrentRC =
    { colorScheme ? "default-16"
    , colorSchemeImport ? "${pyrocore}/lib/pyroscope/color-schemes/${colorScheme}.rc"
    , extraConfig ? ""
    , files ? [ ]
    }:
    let
      files' = defaults ++ [
        { source = colorSchemeImport; optional = true; }
        { name = "_rtlocal.rc"; expr = ''(cat, (cfg.basedir), "_rtlocal.rc")''; optional = true; }
      ] ++ files;
      importConfigs = lib.concatMapStringsSep "\n" (file:
        ''
          # ${file.name or ""}
          ${if file.optional or false then "try_import" else "import"
          } = ${getRcFile file}
        ''
      ) files';
    in writeTextFile {
      name = "rtorrent.rc";
      text = ''
        ${importConfigs}

        # Other additional user settings
        ${extraConfig}
      '';
      checkPhase = checkImports "$out";
    };
}
