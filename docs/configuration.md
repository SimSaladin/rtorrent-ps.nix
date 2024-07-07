# Instance configuration

## RTorrent

File `_rtlocal.rc` inside the instance directory is always read on startup if
it exists. Add commands there to run them at startup.

## Watch directories

File `watch-dirs.rc` in the instance directory is re-read. You can define
actions there to e.g. load torrents from somewhere etc.

```
load.verbose = (cat, (cfg.basedir), "*.torrent")
```

## Tracker aliases

If a file `tracker-aliases.rc` exists in the instance directory, it is loaded
on startup. You can create this file to define tracker aliases.

Refer to tracker foobar-tracker.org as just foobar (e.g. `rtcontrol
alias=foobar ...`):

```
trackers.alias.set_key = foobar-tracker.org, foobar
```
