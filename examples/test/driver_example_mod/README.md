# The Flutter Driver example mod

This is a very simple mod intended to be used with flutter driver testing
scripts.

It contains four buttons that all modify a counter.

## Building

To add the example (with the Flutter Driver Extensions enabled for driving the
mod), run the following:

```
$ fx set x64 --packages topaz/packages/all \
    --packages topaz/packages/tests/examples/misc
```

This will include the package with the topaz build when you run

```
$ fx full-build
```

## Caveats

Testing code is not yet included (this is in progress).
