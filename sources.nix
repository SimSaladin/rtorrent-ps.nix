{ fetchFromGitHub, ... }:

let
  _rtorrent-ps = args: fetchFromGitHub ({
    owner = "pyroscope";
    repo  = "rtorrent-ps";
  } // args);
in
{
  rtorrent-ps = [
    (_rtorrent-ps {
      passthru.version = "1.1-67-g244a4e9";
      rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0";
      hash = "sha256-guyhmTL8Qpakrk2JeO6zFNj2Hg0jSZ5tbPbDDRwKcN0=";
    })

    (_rtorrent-ps {
      passthru.version = "1.1-71-gee296b1";
      rev = "ee296b11fb3d609dfdba97ded57f89782f18e4ad";
      hash = "sha256-DUPZ1oUqtWxJYO6z1rmcVSeutpTX5W9jhhdinN4wK5E=";
    })
  ];

  defaults = {
    rtorrent-ps = "1.1-71-gee296b1";
  };
}
