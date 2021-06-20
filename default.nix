{ nixpkgs ? import <nixpkgs> {} }:

with nixpkgs;

let
  rtpsSrc = fetchFromGitHub {
    owner = "pyroscope";
    repo = "rtorrent-ps";
    rev = "244a4e9fe7e5ed5f21095c4b18a21b06dbc717e0"; # PS-1.1-66-gbac90aa
    sha256 = "1pbh18f0vhzndinrwj931lggdn0lngp7i2admsj9chpw6acs3v42";
  };

  rtpsVersion = "PS-1.1-67-g244a4e9"; # git describe --long --tags

  libtorrent-ps = callPackage ./libtorrent.nix {
    inherit rtpsSrc rtpsVersion;
  };

  rtorrent-ps = callPackage ./rtorrent.nix {
    libtorrent = libtorrent-ps;
    inherit rtpsSrc rtpsVersion;
  };

  ProxyTypes = callPackage ./ProxyTypes.nix {
    buildPythonPackage = python2Packages.buildPythonPackage;
  };

  pyrobase = callPackage ./pyrobase.nix {
    buildPythonPackage = python2Packages.buildPythonPackage;
    six = python2Packages.six;
  };

  pyrocore = callPackage ./pyrocore.nix {
    buildPythonPackage = python2Packages.buildPythonPackage;
    setuptools = python2Packages.setuptools;
    ProxyTypes = ProxyTypes;
    pyrobase = pyrobase;
  };

in rec {
  inherit rtorrent-ps pyrocore;

  rtorrent-env = stdenv.mkDerivation {
    name = "rtorrent-env";
    src = ./.;

    installPhase = ''
      mkdir -p $out/bin

      substitute ${./start.sh} $out/bin/rtorrent-ps \
        --subst-var-by rtorrent ${rtorrent-ps}

      chmod 0755 $out/bin/rtorrent-ps

      mkdir -p $out/rtorrent-home

      substitute ${./rtorrent.rc} $out/rtorrent-home/rtorrent.rc \
        --subst-var-by pyrobin ${pyrocore}/bin \
        --subst-var-by basedir     /media/moore/rtorrent \
        --subst-var-by scgi_socket /media/moore/rtorrent/.scgi_local
    '';
  };
}
