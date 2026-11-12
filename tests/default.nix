{ self, pkgs }:
{
  nixos-module = pkgs.testers.runNixOSTest {
    name = "rtorrent-ps";
    imports = [];
    nodes.server = _: {
      imports = [ self.nixosModules.default ];
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
    name = "rtorrent-ps";
    imports = [];
    nodes.server = _: {
      imports = [ self.nixosModules.default ];
      programs.rtorrent-ps.enable = true;
      services.rtorrent-ps = {
        enable = true;
        daemon = true;
        settings = {
          content = ''
            pyro.category.add = category1
            pyro.category.add = category2
          '';
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
}
