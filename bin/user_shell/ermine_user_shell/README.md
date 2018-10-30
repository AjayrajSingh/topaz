Ermine is a Fuchsia User Shell intended to provide developers with a
lovable environment for testing mods on Fuchsia.

This initial version implements the same approach for view hosting,
layout and control as ``//garnet/bin/developer/[tiles|tiles_ctl]``. For
simplicity it re-uses
``//garnet/public/fidl/fuchsia.developer.tiles/tiles.fidl``.

Much like tiles and `tiles_ctl` there is an `ermine_ctl` program you can
use to add, list and remove mods from Ermine.

When built as part of the default package for topaz, Ermine is launched
by device_runner after the user logs in.

Ermine also responds to stories and mods created with `sessionctl` as shown below.

    /pkgfs/packages/sessionctl/0/bin/app --story_name="Fez Story" --mod_name="noodles1" --mod_url="noodles" add_mod
