Ermine is a Fuchsia Session Shell intended to provide developers with a
lovable environment for testing mods on Fuchsia.

This initial version implements the same approach for view hosting,
layout and control as ``//garnet/bin/developer/[tiles|tiles_ctl]``. For
simplicity it re-uses
``//garnet/public/fidl/fuchsia.developer.tiles/tiles.fidl``.

There is an `ermine_ctl` program you can use to list and remove stories from Ermine. This
program will be removed as soon as sessionctl supports "list" and "remove".

When built as part of the default package for topaz, Ermine is launched
by device_runner after the user logs in.

Ermine also responds to stories and mods created with `sessionctl` as shown below.

    sessionctl --story_name="Fez Story" --mod_name="noodles1" --mod_url="noodles" add_mod
