{ fetchFromGitHub }:
let
  get = attrs: {
    inherit (attrs) version;
    src = fetchFromGitHub {
      owner = "pyroscope";
      repo = "rtorrent-ps";
      inherit (attrs) rev sha256;
    };
  };
in
{
  default = get {
    version = "PS-1.1-67-g244a4e9"; # git describe --long --tags
    rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0";
    sha256 = "1pbh18f0vhzndinrwj931lggdn0lngp7i2admsj9chpw6acs3v42";
  };
}
