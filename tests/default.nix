{ self, pkgs, lib ? pkgs.lib, home-manager, ... }:
let
  common = {
    name = lib.mkDefault "rtorrent-ps";
    nodes.server = {
      imports = [
        self.nixosModules.default
         home-manager.nixosModules.home-manager
       ];
      users.users.nixos = {
        uid = 2000;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        linger = true;
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  };

  homeCommon = {
    imports = [self.hmModules.default];
    home.stateVersion = "26.11";
  };

in
{
  nixos-module = pkgs.testers.runNixOSTest {
    name = "rt-ps-nixos-tui";
    imports = [common];
    nodes.server = _: {
      programs.rtorrent-ps.enable = true;
      services.rtorrent-ps.enable = true;
    };
    testScript = ''
      server.start()
      server.wait_for_unit("multi-user.target")
      server.succeed("systemctl status rtorrent-ps")
      server.wait_for_unit("rtorrent-ps.service")

      server.succeed("rtxmlrpc system.pid")
      server.succeed("su rtorrent-ps -c 'rtxmlrpc system.pid'")

      server.shutdown()
    '';
  };

  nixos-daemon-mode = pkgs.testers.runNixOSTest {
    name = "rt-ps-nixos-headless";
    imports = [common];
    nodes.server = _: {
      programs.rtorrent-ps.enable = true;
      services.rtorrent-ps = {
        enable = true;
        daemon = true;
        settings = {
          set.network.listen.port = 1243;
          set.throttle.global_down = "1234M";
          extraConfig = ''
          '';
          pyro.categories = {
            category1 = { };
            category2 = { };
          };
        };
      };
    };
    testScript = ''
      server.start()
      server.wait_for_unit("multi-user.target")
      server.succeed("systemctl status rtorrent-ps")
      server.wait_for_unit("rtorrent-ps.service")

      server.succeed("rtxmlrpc system.pid")

      server.succeed("systemctl stop rtorrent-ps.service")
      server.shutdown()
    '';
  };

  home-module = pkgs.testers.runNixOSTest {
    name = "rt-ps-hm-tui";
    imports = [ common ];
    #enableDebugHook = true;
    #sshBackdoor.enable = true;
    nodes.server = { config, pkgs, ... } : {
      systemd.services."getty@tty1" = {
        overrideStrategy = "asDropin";
        serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin nixos --noclear --keep-baud %I 115200,38400,9600 $TERM"];
      };
      home-manager.users.nixos = {
        imports = [ homeCommon ];
        programs.rtorrent-ps.enable = true;
        services.rtorrent-ps.enable = true;
      };
    };
    testScript = ''
      server.start()
      # server.succeed('false')
      server.wait_for_unit("multi-user.target")
      server.succeed("su -- nixos -c 'which rtorrent-ps'")
      server.wait_for_unit("rtorrent-ps.service", "nixos")

      server.succeed('systemctl --machine nixos@.host --user status rtorrent-ps')
      server.succeed('systemctl --machine nixos@.host --user is-active rtorrent-ps')

      server.succeed("su nixos -c '${pkgs.writeShellScript "run" ''
        rtxmlrpc system.pid
      ''}'")

      server.succeed('systemctl --machine nixos@.host --user stop rtorrent-ps')

      server.shutdown()
    '';

  };
}
