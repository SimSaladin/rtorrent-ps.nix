{ lib
, stdenv
, symlinkJoin
, substituteAll
, installShellFiles
, writeShellApplication
, makeWrapper
, coreutils
, lsof
, rtorrent-ps-src
, pyrocore
, pyrocoreEnv
, py2
, rtorrents
, callPackage
}:

let
  # PyroScope configuration (default)
  pyroscope = "${pyrocore}/lib/pyroscope";

  inherit (pyrocore.passthru) createImport;


  # The initial rtorrent.rc to load. It imports other configs.
  initRc = substituteAll {
    src = ./main.rtorrent.rc;
    inherit pyroscope;
    rtConfigs = createImport {
      src = ../config/rtorrent.d;
      inherit pyroscope;
    };
  };

  rtorrent-magnet = writeShellApplication {
    name = "rtorrent-magnet";
    text = builtins.readFile ../misc/rtorrent-magnet;
  };

  mkRtorrentPS = callPackage ({ rtorrent
                              , RT_HOME ? "\"$HOME/.rtorrent\""
                              , RT_SOCKET ? "\"$RT_HOME/.scgi_local\""
                              }:
    let
      startScript = writeShellApplication {
        name = "rtorrent-ps";
        text = builtins.readFile ./start.sh;
        runtimeInputs = [ coreutils rtorrent lsof ];
      };

      rtorrent-ps-unwrapped = stdenv.mkDerivation {
        pname = "rtorrent-ps";
        version = rtorrent-ps-src.version;

        src = rtorrent-ps-src.src;

        nativeBuildInputs = [
          makeWrapper
          installShellFiles
          (py2.withPackages (ps: with ps; [ sphinx sphinx_rtd_theme ]))
        ];

        postBuild = ''
          # Build documentation
          make -C docs html man
        '';

        postInstall = ''
          # man page
          installManPage docs/build/man/rtorrent-ps.1

          # HTML docs
          mkdir -p $out/share/doc/rtorrent-ps/
          mv docs/build/html $out/share/doc/rtorrent-ps/
        '';
      };

      rtorrent-ps = symlinkJoin rec {
        name = "rtorrent-ps-${rtorrent-ps-unwrapped.version}_${rtorrent.version}";
        paths = [
          startScript
          rtorrent-magnet
          pyrocore
          rtorrent
          rtorrent-ps-unwrapped
        ];

        nativeBuildInputs = [ makeWrapper ];

        makeWrapperArgs = lib.concatStringsSep " " [
          "--prefix PATH : $out/bin"
          "--run 'export RT_HOME=\${RT_HOME-${RT_HOME}}'"
          "--run 'export RT_SOCKET=\${RT_SOCKET-${RT_SOCKET}}'"
          "--set-default RT_INITRC ${initRc}"
          "--set-default PYRO_CONFIG_DIR ${pyroscope}"
        ];

        postBuild = ''
          rm -rf $out/EGG-INFO

          # Wrap executables with the proper environment
          for exe in $out/bin/*; do
            wrapProgram "$exe" ${makeWrapperArgs}
          done

          # A python interpreter with the appropriate packages available
          makeWrapper ${pyrocoreEnv.interpreter} $out/bin/python-pyrocore ${makeWrapperArgs}
        '';

        passthru.pkgs = {
          inherit rtorrent-ps-unwrapped startScript initRc;
        };

      };
    in
    rtorrent-ps);

  # by rtorrent version
  versions = {
    rtorrent-ps_096    = mkRtorrentPS { rtorrent = rtorrents.rtorrent_0_9_6; };
    rtorrent-ps_097    = mkRtorrentPS { rtorrent = rtorrents.rtorrent_0_9_7; };
    rtorrent-ps_098    = mkRtorrentPS { rtorrent = rtorrents.rtorrent_0_9_8; };
    rtorrent-ps_master = mkRtorrentPS { rtorrent = rtorrents.rtorrent_master; };
    rtorrent-ps_stable = versions.rtorrent-ps_096;
    rtorrent-ps_latest = versions.rtorrent-ps_master;
    rtorrent-ps        = versions.rtorrent-ps_latest;
  };

  topPkgs = with builtins; lib.concatMapAttrs (v: rt: {
    "rtorrentPSPkgs${substring (stringLength "rtorrent-ps") (-1) v}" = rt.pkgs;
  }) versions;

in versions // topPkgs // {
  inherit mkRtorrentPS pyrocoreEnv createImport rtorrent-magnet;
}
