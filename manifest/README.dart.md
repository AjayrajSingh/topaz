# Dart dependency in Fuchsia

The Fuchsia build pulls a version of the Dart SDK that matches the version used in Flutter.
The `revision` field in [`dart`](dart) should match the `dart_revision` value in
[Flutter's `DEPS` file](https://github.com/flutter/engine/blob/master/DEPS).
The other entries in [`dart`](dart) and
[`dart_third_party_pkg`](dart_third_party_pkg) should correspond to the
values in the [Dart SDK `DEPS` file](https://github.com/dart-lang/sdk/blob/master/DEPS).

## Updating Fuchsia's version of Dart

* Update `flutter/engine`.
* Update the [dart](dart) manifest's `revision` field of the `dart/sdk` entry:
  ```shell
  jiri edit -project=dart/sdk=123abcdef topaz/manifest/dart
  ```
* If needed, update the other `revision` fields in the [dart](dart) manifest:
  ```shell
  jiri edit -project=observatory_pub_packages=456abcdef topaz/manifest/dart
  ```
* Update your local tree by running `jiri update -local-manifest=true`.
  * This will run a hook that:
    * Verifies the prebuilts are ready for all host platforms.
    * Downloads the prebuilt for the current host platform.
  * If this fails:
    * Check on Fuchsia's [prebuilt Dart builder bots](https://luci-milo.appspot.com/p/fuchsia/g/dart/console).
      * If they're still running for your chosen revision, wait for them to
        finish and then try again later.
    * Ask [`fuchsia-toolchain@`](mailto:fuchsia-toolchain@google.com) for help.
* Update the [`dart_third_party_pkg`](dart_third_party_pkg) manifest by
  running `//third_party/dart/tools/create_pkg_manifest.py`.
* Build and verify that everything works.
* Land the changes.

The manifests [`dart_head`](dart_head) and
[`dart_third_party_pkg_head`](dart_third_party_pkg_head) pull the Dart SDK
sources from top-of-tree.
[`dart_third_party_pkg_head`](dart_third_party_pkg_head) will need to be
periodically updated with `//third_party/dart/tools/create_pkg_manifest.py` as
well.
