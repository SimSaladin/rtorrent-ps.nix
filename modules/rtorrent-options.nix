{ lib, ... }:

let
  inherit (lib) types mkOption;

  showOptions = attrs:
    lib.concatLines (lib.mapAttrsToListRecursiveCond
        (_: _: true)
        (path: val: "${lib.concatStringsSep "." path}${if lib.last path ==
          "set" then "" else ".set"} = ${toString val}")
        attrs);

  methodType = types.submodule ({ name, ... }: {
    options = {
      kind = mkOption {
        # multi rlookup
        type = types.enum [ "multi" "simple" "value" "bool" "string" "list" ];
        default = "simple";
      };
      rlookup = mkOption {
        type = types.bool;
        default = false;
        description = "Only relevant for multi type";
      };
      private = mkOption {
        type = types.bool;
        default = false;
      };
      static = mkOption {
        type = types.bool;
        default = false;
      };
      const = mkOption {
        type = types.bool;
        default = false;
      };
      name = mkOption {
        type = types.singleLineStr;
        default = name;
        description = "The unique name of this method.";
      };
      text = mkOption {
        type = types.nullOr commandTextType;
        description = "The command to run";
        default = null;
      };
    };
  });

  showMethod = x:
  let type = x.kind
    + lib.optionalString x.rlookup "|rlookup"
    + lib.optionalString x.const "|const"
    + lib.optionalString x.static "|static"
    + lib.optionalString x.private "|private"
    ;
  in
  "method.insert = ${x.name}, ${type}${
    lib.optionalString (x.text != null) ", ${x.text}"}";

  intervalType = types.oneOf [ types.int types.singleLineStr ];

  commandTextType = types.str;

  scheduleType = types.submodule ({ name ? null, ... }: {
    options = {
      name = mkOption {
        type = types.singleLineStr;
        default = name;
        description = "The unique name of this schedule";
      };
      start = mkOption {
        type = intervalType;
        default = 0;
        description = "Start time";
      };
      interval = mkOption {
        type = intervalType;
        default = 0;
        description = "Run interval";
      };
      text = mkOption {
        type = commandTextType;
        description = "The action";
      };
    };
  });

  watchDirectoryType = types.submodule ({ name, ... }: {
    options = {
      type = mkOption {
        type = types.enum [ "added" "ready" ];
      };
      path = mkOption {
        type = types.singleLineStr;
        default = name;
        description = "The path to watch";
      };
      expr = mkOption {
        type = commandTextType;
        description = "The action to perform on added file.";
      };
    };
  });

  showSchedule = { name, start, interval, text }:
  "schedule = ${name}, ${toString start}, ${toString interval}, ${text}";

  showWatchDirectory = x:
   ''
   branch = (os.path.exists,"${x.path}"), ((directory.watch.${x.type}, "${x.path}", ${x.expr}))'';
in

  { config, ... }: {

  #freeformType = types.attrsOf types.raw;

  options = {
    methods = mkOption {
      type = types.attrsOf methodType;
      default = { };
      description = ''
        Custom methods to define.
      '';
    };
    schedules = mkOption {
      type = types.attrsOf scheduleType;
      default = { };
      description = ''
        Scheduled actions to define.
      '';
    };

    throttle =
      let
        max_rate = {
          max_rate = mkOption {
            type = with types; nullOr (either int str);
            default = null;
            description = ''
              throttle.FOO.BAR.set = INT
              throttle.FOO.BAR.set_kb = STR
            '';
          };
        };
        numpeers = mkOption {
          type = with types; nullOr ints.positive;
          default = null;
          description = ''
            Max/min number of peers/slots.
          '';
        };
      in
      {
      global_up = max_rate;
      global_down = max_rate;
      max_downloads.set =  numpeers;
      max_downloads.global.set =  numpeers;
      max_uploads.set =  numpeers;
      max_uploads.global.set =  numpeers;
      min_downloads.set =  numpeers;
      max_peers.seed.set =  numpeers;
      max_peers.normal.set =  numpeers;
      min_peers.seed.set =  numpeers;
      min_peers.normal.set =  numpeers;
    };

    options = mkOption {
      type = with types;
        let
          type = oneOf [ int str bool (attrsOf type) ];
          type' = oneOf [ int str bool (attrsOf raw) ];
        in
        attrsOf type // { inherit (type') description; };
      default = { };
      description = ''
        Simple "foo.set = value" options.
      '';
    };

    pyro.categories = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      description = ''
        Categories, often decided by which tracker a torrent came from. The empty
        string category is for uncategorized items.
      '';
    };

    trackerAlias = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Tracker aliases.
      '';
    };

    dht.nodes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of dht nodes to bootstrap with.
      '';
    };

    directory.watch = mkOption {
      type = types.attrsOf watchDirectoryType;
      default = { };
    };

    content = mkOption {
      type = types.lines;
      default = "";
    };
  };

  config = {
    pyro.categories."" = { };

    options = {
      system.umask = "0027";
      keys.layout = "dvorak";
      protocol.pex = true;
      trackers.numwant = 80;
    };

    throttle = {
      min_peers.normal.set = 20;
      max_peers.normal.set = 60;
      min_peers.seed.set = 30;
      max_peers.seed.set = 80;
      max_uploads.set = 100;
      max_uploads.global.set = 250;
      max_downloads.set = 50;
      max_downloads.global.set = 250;
    };

    methods = {
    };

    schedules = {
      "local_address.ipv4" = {
        interval = 300;
        text = "((myip.update.ipv4, ((myip.opendns.ipv4))))";
      };
      "local_address.ipv6" = {
        interval = 300;
        text = "((myip.update.ipv6, ((myip.opendns.ipv6))))";
      };
    };

    trackerAlias = {
      "nyaa.tracker.wf" = "Nyaa";
      "tleechreload.org" = "TorrentLeech";
      "torrentleech.org" = "TorrentLeech";
      "bt.t-ru.org" = "RuTracker";
      "bt2.t-ru.org" = "RuTracker";
      "bt3.t-ru.org" = "RuTracker";
      "bt4.t-ru.org" = "RuTracker";
    };

    directory.watch = {
      "~/Downloads" = {
        type = "added";
        expr = "load.start_verbose.if_exists";
      };
    };

    content = ''
      ###############
      ### Options ###
      ###############
      ${showOptions config.options}

      #################
      ### Throttles ###
      #################
      ${lib.concatMapStringsSep "" (path:
        let val = lib.getAttrFromPath path config.throttle;
        in lib.optionalString (!isNull val) "throttle.${lib.concatStringsSep "." path}.set_kb = ${toString val}\n"
      ) [
          [ "global_up" "max_rate" ]
          [ "global_down" "max_rate" ]
        ]}

      ${lib.concatMapStringsSep "" (path:
        let val = lib.getAttrFromPath (path ++ [ "set" ]) config.throttle;
        in lib.optionalString (!isNull val) "throttle.${lib.concatStringsSep "." path}.set = ${toString val}\n"
      ) [
          [ "max_downloads" ]
          [ "max_downloads" "global" ]
          [ "max_uploads" ]
          [ "max_uploads" "global" ]
          [ "min_downloads" ]
          [ "min_peers" "seed" ]
          [ "min_peers" "normal" ]
          [ "max_peers" "seed" ]
          [ "max_peers" "normal" ]
        ]}

      ##################
      ### Categories ###
      ##################
      ${lib.concatMapAttrsStringSep "\n" (k: _: "pyro.category.add = \"${k}\"")
        config.pyro.categories}

      #######################
      ### Tracker aliases ###
      #######################
      ${lib.concatMapAttrsStringSep "\n" (k: v: "trackers.alias.set_key = \"${k}\", \"${v}\"") config.trackerAlias}

      #################
      ### DHT Nodes ###
      #################
      ${lib.concatMapStringsSep "\n" (addr:
         ''schedule = "dht_node:${addr}", 5, 0, ((dht.add_node, "${addr}"))'') config.dht.nodes}

      #################
      ### Schedules ###
      #################
      ${lib.concatMapAttrsStringSep "\n" (_: showMethod) config.methods}
      ${lib.concatMapAttrsStringSep "\n" (_: showSchedule) config.schedules}

      #########################
      ### Watch directories ###
      #########################
      ${lib.concatMapAttrsStringSep "\n" (_: showWatchDirectory) config.directory.watch}
    '';
  };
}
