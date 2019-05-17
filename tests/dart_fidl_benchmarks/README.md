# Dart FIDL Microbenchmarks

This is a small set of benchmarks that we use to evaluate changes to the Dart
FIDL bindings, in particular encoding and decoding.

So far it contains benchmarks for:
 - string encoding and decoding, both ASCII and Unicode

You can include this in your build by including the target:
`//topaz/packages/tests:dart_fidl_benchmarks`.  If you use `fx` that means
passing `--with //topaz/packages/tests:dart_fidl_benchmarks` to `fx set`.

You can run the benchmarks by invoking:
```
fx shell run 'fuchsia-pkg://fuchsia.com/dart_fidl_benchmarks#meta/dart_fidl_benchmarks.cmx'
```
this will print output like:
```
ascii string encoding: 1.981835495845084us
unicode string encoding: 2.1020481305960463us
ascii string decoding: 1.2789800901169373us
unicode string decoding: 5.850596467415152us
```

This is most useful while considering whether to land a change to the bindings.
