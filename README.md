# `rtorrent-ps.nix`

RTorrent with all Pyroscope extras packaged as a Nix derivation.

Installation:

```bash
nix-build              # RT_HOME defaults to ~/.rtorrent
nix build --impure     # pass --impure if using the new interface

# Configuring RT_HOME:
nix-build --argstr RT_HOME /data/rtorrent
nix build --impure --expr '(builtins.getFlake (toString ./.)).defaultPackage.${builtins.currentSystem}.override { RT_HOME = "/data/foo"; }'
```

Configuration files read from RT_HOME (if they exist):

- `tracker-aliases.rc`
- `watch-dirs.rc`
