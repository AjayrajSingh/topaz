# Dart dependency in Fuchsia

The Fuchsia build pulls a version of the Dart SDK that matches the version used in Flutter.
The `revision` field in [dart](dart) should match the `dart_revision` value in
[Flutter's DEPS file](https://github.com/flutter/engine/blob/master/DEPS).
The other entries in [dart](dart) and [dart\_third\_party\_pkg](dart_third_party_pkg) should
correspond to the values in the [Dart SDK deps file](https://github.com/dart-lang/sdk/blob/master/DEPS).

## Updating Fuchsia's version of Dart

* Update flutter/engine
* Update the [dart](dart) manifest's `revision` field of the external/github.com/dart-lang/sdk entry.
* If needed, update the other `revision` fields in the [dart](dart) manifest, for example
observatory\_pub\_packages.
* Update your local tree by running `jiri update -local-manifest=true`
* Update the [dart\_third\_party\_pkg](dart_third_party_pkg) manifest by running
`//third_party/dart/tools/create_pkg_manifest.py`
* Build and verify that everything works
* Land the changes

The manifests [dart\_head](dart_head) and [dart\_third\_party\_pkg\_head](dart_third_party_pkg_head)
pull the Dart SDK sources from top-of-tree. [dart\_third\_party\_pkg\_head](dart_third_party_pkg_head)
will need to be periodically updated with `//third_party/dart/tools/create_pkg_manifest.py`
as well.
