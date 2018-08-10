# The Flutter Driver example mod

This is a very simple mod intended to be used with flutter driver testing
scripts.

It contains four buttons that all modify a counter.

## Building

To add the example (with the Flutter Driver Extensions enabled for driving the
mod), run the following:

```
$ fx set x64 --packages topaz/packages/all \
    --packages topaz/packages/examples/tests
```

This will include the package with the topaz build when you run

```
$ fx full-build
```

## Testing

This mod is referenced in
`//topaz/tests/modular_integration_tests/topaz_modular_integration_tests.json`,
using the `driver_example_mod` as the mod under test, and the test code built
from this `BUILD.gn` file as the integration testing code to be run against
`driver_example_mod`.

You can run these tests using the following command (so long as you've added
`//topaz/packages/tests/all` as one of the packages for your build):

```
$ fx shell /pkgfs/packages/topaz_modular_integration_tests/0/bin/run_topaz_modular_integration_tests.sh
```
