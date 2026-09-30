{ lib
, callPackage
, coreutils
, fetchFromGitHub
, installShellFiles
, lndir
, lsof
, makeWrapper
, pyrocore
, stdenv
, writeShellApplication

, rtorrentVersions
, rtorrent-config
, rtorrent-magnet

, RT_HOME ? "\"$HOME/.rtorrent\""
, RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
, PYRO_CONFIG_DIR ? "${pyrocore}/lib/pyroscope"
, colorScheme ? "solarized-blue"
}@args:

let
  builder =
    { version
    , src
    , rtorrent
    , writeInitRc
    , writeStartScript
    }@bargs:
    let
      initRc = writeInitRc { inherit colorScheme; };
    in
    import ./unwrapped.nix (args // bargs // {
      version = "${version}+${rtorrent.version}";

      inherit initRc;

      startScript = { pname, ... }:
        writeStartScript {
          inherit pname;
          inherit initRc;
          inherit rtorrent RT_HOME RT_SOCKET PYRO_CONFIG_DIR;
        };
    })
    ;

in
lib.recurseIntoAttrs rec {

  src = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
    hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
  } // {
    version = "1.1-71-gee296b1";
  };

  writeInitRc = { colorScheme ? "solarized-blue" }:
    rtorrent-config.createRtorrentRC {
    inherit colorScheme;
    extraConfig = ''
      ui.color.odd.set = "on 0"
      ui.color.even.set = ""
    '';
  };

  writeStartScript = { pname, rtorrent, RT_HOME, RT_SOCKET, PYRO_CONFIG_DIR, initRc }:
  writeShellApplication {
    name = pname;
    text = ''
      export RT_HOME=''${RT_HOME-${RT_HOME}}
      export RT_SOCKET=''${RT_SOCKET-${RT_SOCKET}}
      ${builtins.readFile ./start.sh}
    '';
    runtimeInputs = [ coreutils lsof ];
    runtimeEnv = {
      RT_BIN = lib.getExe rtorrent;
      RT_INITRC = initRc + "/rtorrent.rc";
      PYRO_CONFIG_DIR = PYRO_CONFIG_DIR;
    };
  };

  rtorrent-ps_1_1-71-gee296b1 = builder {
    version = src.version;
    src = src;
    rtorrent = rtorrentVersions.latest;
    inherit writeInitRc writeStartScript;
  };

  # passthru.version = "1.1-67-g244a4e9";
  # rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0";
  # hash = "sha256-guyhmTL8Qpakrk2JeO6zFNj2Hg0jSZ5tbPbDDRwKcN0=";
  #

  latest = rtorrent-ps_1_1-71-gee296b1;

  unwrapped = callPackage ./unwrapped.nix {
    src = src;
  };
}
