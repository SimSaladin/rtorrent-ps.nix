# categories

Configure watch directories in `$RT_HOME/watch-dirs.rc` (automatically reloaded).

**TODO: is this empty category necessary?**

```
# "Other" category for empty labels
pyro.category.add = (cat,)
```

## Setup categories

- Define categories: `pyro.category.add = hdtv`.

## Managing categories

- Set category of an item: `d.category.set = <category>`
- Get category: `d.custom = category`

```
rtcontrol tracker=foobar --exec="d.category.set=asdf"
```

## Category views

Named like `category_<category>`

- List category views:              `python-pyrocore -m pyrocore.ui.categories -l`
- Rotate to next view (key `>`):      `python-pyrocore -m pyrocore.ui.categories -qn`
- Rotate to previous view (key `<`):  `python-pyrocore -m pyrocore.ui.categories -qp`
- Re-filter current view:           `python-pyrocore -m pyrocore.ui.categories -qu`

## Load categorized items

- `load.category = <category>`: Load categorized items (sets the ruTorrent label, and define a view).
- `load.category.normal = <category>`: only load categorized items.
- `load.category.start = <category>`: load and start categorized items.

Categorized items are loaded from `<watch_dir>/<category>/*.torrent`.

## Startable

- `cfg.watch.start=1`
- `d.watch.startable`
- `d.watch.start`

## Example

Add in `$RT_HOME/watch-dirs.rc`:

```
pyro.category.add = hdtv
schedule2 = watch_hdtv, 10, 10, ((load.category, hdtv))
```
