# Driver Example Test Directory.

This is very much a work in progress. A few things to note: there should not be
a pubspec.yaml in here in the future. This is a placeholder for when things are
eventually fleshed out more.

To run tests in this directory, first run `${TOPAZ_FLUTTER_ROOT}/bin/flutter
packages get` to get all packages in this directory. Then run
`${FUCHSIA_DART_SDK_ROOT}/dart ${TEST}.dart`.

Make sure the driver example mod (`driver_example_mod_wrapper`) is running on
your device for these tests, as they are intended as integration testing
examples.

Once more tooling is put into place to automate a lot of this, this README will
be deprecated and removed, along with the `pubspec.yaml` file.
