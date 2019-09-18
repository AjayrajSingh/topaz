# The Flutter Driver example mod

This is a very simple mod intended to be used with flutter driver testing
scripts.

It contains four buttons that all modify a counter.

## Building

To add the example (with the Flutter Driver Extensions enabled for driving the
mod), run the following:

```
$ fx set core.[chromebook-][x64|arm64] --with //topaz/examples/test/driver_example_mod:driver_example_mod_tests --with //topaz/bundles:buildbot
```

This will include the package and its dependencies with the topaz build when
you run

```
$ fx build
$ fx serve
```

## Testing

You can then run these tests using the following command:

```
$ fx run-test driver_example_mod_tests
```
