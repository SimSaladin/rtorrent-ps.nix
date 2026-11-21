{ lib
, writeTextFile
, pyrocore
}:

let

  defaultImports = [
    { source = ./helpers.rc; name = "helpers"; }
    { source = ./constants.rc; name = "constants"; }
    { source = ./systemd-notify.rc; }
    { text = pyrocore.rtorrentConfigString; name = "pyroscope"; }
    { source = ./instance-layout.rc; name = "instance-layout"; }
    { source = ./disable-control-q.rc; }
    { source = ./logging.rc; }
    { source = ./ps-columns.rc; }
    { source = ./settings.rc; name = "general settings"; }
    { source = ./myip.rc; }
    { source = ./network-history.rc; }
    { source = ./watch-disk-space.rc; }
    { source = ./tracker-aliases.rc; }
    { source = ./views.rc; }
    { source = ./watch-dirs.rc; }
    {
      name = "pyrotorque";
      text = ''
        # TORQUE: Daemon watchdog schedule
        # Must be activated by touching the "$RT_HOME/run/pyrotorque" file!
        # Set the second argument of 'pyro.watchdog' to "-v" or "-q" to change
        # log verbosity.
        schedule = pyro_watchdog, 30, 300, ((pyro.watchdog, (cfg.basedir)))
      '';
    }
    { name = "_rtlocal.rc"; expr = ''(cat, (cfg.basedir), "_rtlocal.rc")''; optional = true; }
  ];

  mkImports = lib.concatMapStrings (
    x@{ name ? "", optional ? false, ... }: ''
      ${lib.optionalString (name != "") ''# ${name}
      ''}${if optional then "try_import.if_exists" else "import"} = ${getRcFile x}
      print = "Done loading config ${toString (x.source or x.name or "unk")}"
    ''
  );

  getRcFile = { source ? null, text ? null, expr ? null, name ? "rtorrent.rc", ... }:
    if !builtins.isNull source then ''"${source}"''
    else if !builtins.isNull text then ''"${builtins.toFile name text}"''
    else if !builtins.isNull expr then expr
    else lib.throw "At least one of [source, text, expr] must be defined and not null";
in
{
  createRtorrentRC = { files ? [ ], extraConfig ? null }:
    let
      finalImports = defaultImports ++ files ++
        lib.optional (extraConfig != null) { text = extraConfig; name = "user extra config"; };
    in
    writeTextFile {
      name = "rtorrent.rc";
      text = mkImports finalImports;
      checkPhase = ''
        source ${./helpers.sh}
        checkImports "$out"
      '';
    };
}
