# RTorrent-PS for Nix/NixOS

This flake provides the following:

- RTorrent-PS packages.
- NixOS and Home Manager modules useful for running RTorrent.

## Quickstart

```bash
# Build latest rtorrent-ps
nix build .#rtorrent-ps

# Set custom RT_HOME:
nix build --impure --expr '(builtins.getFlake (toString ./.)).defaultPackage.${builtins.currentSystem}.override { RT_HOME = "/data/foo"; }'
```

## Advanced Configuration

**TODO:** Do something similar to
<https://github.com/pyroscope/pimp-my-box/tree/master>.

- The `pyrocore.passthru.createImport` function can be used to help with
  importing all config files contained within a directory (`rtorrent.d`).

## Links and Resources

- rtorrent Handbook <https://rtorrent-docs.readthedocs.io>
- docker-rtorrent-rutorrent <https://github.com/crazy-max/docker-rtorrent-rutorrent>
