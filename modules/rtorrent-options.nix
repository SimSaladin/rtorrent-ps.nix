#
# Common module of Nix options for rtrorrent configuration.
#
{ lib, config, ... }:

let
  inherit (lib) types mkOption;

  # For defining "method.insert =..."
  #
  #   method.insert = {name}, {type}[flags...], {text}
  #
  methodType = types.submodule ({ name, ... }: {
    options = {
      name = mkOption {
        type = types.singleLineStr;
        default = name;
        description = ''
          The unique name of this method.
        '';
      };
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
      text = mkOption {
        type = types.nullOr commandTextType;
        description = "The command to run";
        default = null;
      };
    };

    config = { };
  });

  # Intervals for "schedule = " etc. Example values
  #
  #   singular number (seconds)   4242
  #   DD:HH:MM:SS                 00:12:01:12
  #
  # TODO incomplete
  intervalType = types.oneOf [ types.int types.singleLineStr ];

  # A piece of rtorrent config code.
  #
  # TODO incomplete
  commandTextType = types.str;

  # A scheduled action:
  #
  #   "schedule = {name}, {start}, {interval}, {text}"
  #
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
    config = { };
  });

  # Watch directory specification
  #
  #  directory.watch.{type} = {path}, {expr}
  #
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
    config = { };
  });

  simpleNestedSettingsType =
    with types;
    let
      base = inner: oneOf [ bool int str (attrsOf inner) ];
      nest = base nest;
    in
    attrsOf nest // {
      inherit (base raw) description; #  To avoid infinite recursion
    };

  setsPathOption = path: attrs@{ type, ... }:
    let
      setOptionType = path: attrs: types.submodule {
        options = lib.setAttrByPath path
          (lib.mkOption
            {
              type = with types; oneOf [ bool int str ];
            } // attrs);
      };
      args = {
        type = types.nullOr type;
        description = "Alternative path ${toString path}";
      } // lib.removeAttrs attrs [ "type" ];
    in
    if path == [ ] then mkOption args else
    mkOption {
      type = with types; nullOr (coercedTo args.type (lib.setAttrByPath path) (setOptionType path args));
      inherit (args) description;
    };

  fmtNestedSettings = cfgas:
    let
      go = path: as: let
          recurse = n:
            if (lib.tryEval as.${n}).success then
              go (path ++ [ n ]) as.${n}
            else [ ];
        in
        if lib.isAttrs as && !(as?_leaf) then
          lib.concatMap recurse (lib.attrNames as)
        else
          lib.optional (as != null) {
            option = lib.concatStringsSep "." (path ++ lib.optionals (lib.isAttrs as) (as._key or [ ]));
            value = if lib.isAttrs as then as._value else as;
          };
    in
    lib.concatMapStringsSep "\n"
      ({ option ? "", value ? "" }:
        "${option} = ${fmtValue value}"
      )
      (go [ ] cfgas);

  fmtValue = val:
    if lib.isBool val then if val then "yes" else "no"
    else if lib.isStringLike val || lib.isInt val || lib.isFloat val then toString val
    else builtins.throw "unhandled type: ${lib.typeOf val}";

  fmtMethodType = main: attrs:
    let f = x: lib.optional (attrs.${x} or false) x; in
    lib.concatStringsSep "|" ([ main ] ++ f "rlookup" ++ f "const" ++ f "static" ++ f "private");

  fmtMethod = x@{ name, kind, text ? null, ... }: ''
    method.insert = ${name}, ${fmtMethodType kind x}${
    lib.optionalString (text != null) ", ${text}" }
  '';

  fmtSchedule = { name, start, interval, text }: ''
    schedule = ${name}, ${fmtValue start}, ${fmtValue interval}, ${text}
  '';

  fmtDirectoryWatch = { path, type, expr }: ''
    branch = (os.path.exists,"${path}"), ((directory.watch.${type}, "${path}", ${expr}))
  '';

  slotsOption = as: setsPathOption [ "set" ] ({
    type = types.ints.positive;
    description = "Set the number of min/max slots";
  } // as);

  setValue = path: v: { _key = path; _leaf = true; _value = v; };
in
{
  options = {
    set = mkOption {
      type = types.submodule {
        freeformType = simpleNestedSettingsType;
        options = {
          network = {
            listen.port = lib.mkOption {
              type = types.raw; # XXX
              apply = as:
                if as.range or null != null then setValue [ "range" "set" ] as.range
                else if as.random or null != null then setValue [ "random" "set" ] as.random
                else if as.set or null != null then setValue [ "set" ] as.set
                else setValue [ "set" ] as;
              description = ''
                Network listening port. Many possible values:

                  (1) network.listen.port.range.set = <RANGE>

                  (2) network.listen.port.set = <PORT>

                  (3) network.listen.port.random.set = <BOOL>
              '';
            };
            prefer.ipv6 = setsPathOption [ "set" ] {
              type = types.bool;
              description = ''Prefer IPv6 connections'';
            };
            max_open_sockets = setsPathOption [ "set" ] {
              type = types.int;
            };
            send_buffer.size = setsPathOption [ "set" ] {
              type = types.str;
            };
          };
          throttle = {
            global_up = setsPathOption [ "max_rate" "set_kb" ] {
              type = types.str;
              description = ''
                throttle.FOO.BAR.set = INT
                throttle.FOO.BAR.set_kb = STR
              '';
            };
            global_down = setsPathOption [ "max_rate" "set_kb" ] {
              type = types.str;
              description = ''
                throttle.FOO.BAR.set = INT
                throttle.FOO.BAR.set_kb = STR
              '';
            };
            max_downloads.set = setsPathOption [ ] {
              type = types.ints.positive;
              description = "Set max downloads";
            };
            max_uploads.set = setsPathOption [ ] {
              type = types.ints.positive;
              description = "Set max uploads";
            };
            max_downloads.global = slotsOption { };
            max_uploads.global = slotsOption { };
            min_downloads = slotsOption { };
            min_uploads = slotsOption { };
            max_peers.seed = slotsOption { };
            max_peers.normal = slotsOption { };
            min_peers.seed = slotsOption { };
            min_peers.normal = slotsOption { };
          };
          trackers = {
            numwant = setsPathOption [ "set" ] {
              type = types.ints.positive;
            };
          };
          system = {
            file.allocate = setsPathOption [ "set" ] {
              type = types.bool;
            };
            umask = setsPathOption [ "set" ] {
              type = types.str;
            };
            sockets.files.min_alloc = setsPathOption [ "set" ] {
              type = types.ints.positive;
            };
          };
          keys.layout = setsPathOption [ "set" ] {
            type = types.str;
          };
          protocol.pex = setsPathOption [ "set" ] {
            type = types.bool;
          };
          pieces = {
            memory.max = setsPathOption [ "set" ] {
              type = types.str;
            };
            preload = {
              min_rate = setsPathOption [ "set" ] {
                type = types.str; # TODO
              };
              min_size = setsPathOption [ "set" ] {
                type = types.str; # TODO
              };
              type = setsPathOption [ "set" ] {
                type = types.enum [ 0 1 2 ];
              };
            };
          };
        };
      };
      default = { };
      description = ''
        Freeform settings for simple options:

          ```
          {
            foo.bar = 42;
            some.other.setting = "Hello";
          }
          ```

        Becomes

          ```
          foo.bar.set = 42
          some.other.setting.set = "Hello"
          ```

        Simple "foo.set = value" options.
      '';
    };

    trackerAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Tracker aliases. Value is alias for the key.
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
      description = ''
        Directory watches to create.
      '';
    };

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

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Additional configuration file content. Appended to the generated
        rtorrent.rc
      '';
    };

    generatedConfig = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = "The generated rtorrent.rc contents.";
    };
  };

  config = {
    set = {
      #network.listen.port = lib.mkDefault { range = "61000-62000"; };
      system.umask = "0027";
      keys.layout = "dvorak";
      protocol.pex = true;
      trackers.numwant = 80;
      network.prefer.ipv6.set = true;
      throttle = {
        min_peers.normal = 20;
        max_peers.normal = 60;
        min_peers.seed = 30;
        max_peers.seed = 80;
        max_uploads.set = 100;
        max_uploads.global = 250;
        max_downloads.set = 50;
        max_downloads.global = 250;
      };
    };

    methods = { };

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

    pyro.categories."" = { };

    trackerAliases = {
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

    generatedConfig = ''
      #######################
      ### Simple settings ###
      #######################
      ${fmtNestedSettings config.set}

      ##################
      ### Categories ###
      ##################
      ${lib.concatMapAttrsStringSep "\n" (k: _: "pyro.category.add = \"${k}\"")
        config.pyro.categories}

      #######################
      ### Tracker aliases ###
      #######################
      ${lib.concatMapAttrsStringSep "\n" (k: v: "trackers.alias.set_key = \"${k}\", \"${v}\"")
        config.trackerAliases}

      #################
      ### DHT Nodes ###
      #################
      ${lib.concatMapStringsSep "\n" (addr:
         ''schedule = "dht_node:${addr}", 5, 0, ((dht.add_node, "${addr}"))'') config.dht.nodes}

      ###############
      ### Methods ###
      ###############
      ${lib.concatMapAttrsStringSep "\n" (_: fmtMethod) config.methods}

      #################
      ### Schedules ###
      #################
      ${lib.concatMapAttrsStringSep "\n" (_: fmtSchedule) config.schedules}

      #########################
      ### Watch directories ###
      #########################
      ${lib.concatMapAttrsStringSep "\n" (_: fmtDirectoryWatch) config.directory.watch}

      ###########################
      ### Additional settings ###
      ###########################
      ${config.extraConfig}
    '';
  };
}
