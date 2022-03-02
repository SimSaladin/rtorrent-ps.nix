# categories

Configure watch directories in `$RT_HOME/watch-dirs.rc` (automatically reloaded).

**TODO: is this empty category necessary?**

```
# "Other" category for empty labels
pyro.category.add = (cat,)
```

## Setup categories

Define categories: `pyro.category.add = hdtv`.

## Load categorized items

- `load.category = <category>`: Load categorized items (sets the ruTorrent label, and define a view).
- `load.category.normal = <category>`: only load categorized items.
- `load.category.start = <category>`: load and start categorized items.

Categorized items are loaded from `<watch_dir>/<category>/*.torrent`.

## Example

Add in `$RT_HOME/watch-dirs.rc`:

```
pyro.category.add = hdtv
schedule2 = watch_hdtv, 10, 10, ((load.category, hdtv))
```
