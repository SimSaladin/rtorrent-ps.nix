{ writeShellApplication }:

writeShellApplication {
  name = "rtorrent-magnet";
  text = builtins.readFile ./rtorrent-magnet;
}
