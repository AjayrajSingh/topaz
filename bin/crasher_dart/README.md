Utility program to simulate a Dart program throwing an unhandled exception,
resulting in a Dart crash caught by the C++ Dart VM runner. The program can be
run as follows:

```sh
$ run fuchsia-pkg://fuchsia.com/crasher_dart#meta/crasher_dart.cmx [<async|sync|exit>]
```

*   *async* throws an exception from an async function
*   *sync* throws an exception from a sync function
*   *exit* calls the disallowed io::exit() function
