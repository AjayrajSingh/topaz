# The Fuchsia Driver Library

This library is a wrapper for the `flutter_driver` library that allows for
`flutter_driver` tests and scripts to run either as a target application
(running on a Fuchsia device), or as a remote-to-target test (a test that will
connect to the Fuchsia device to run a `flutter_driver` script).

## Using this library

*Note:* the mod you are trying to drive _must already be running_ in order for
you to be able to connect to it. Doing this automatically is outside of the
scope of this library. Please instead refer to
`//topaz/tests/modular_integration_tests` for how to run mods along with driver
tests simultaneously.

First, make sure you've got a cursory familiarity with the `flutter_driver`
library
[api available here](https://docs.flutter.io/flutter/flutter_driver/flutter_driver-library.html),
and [some examples here](https://flutter.io/testing/). This is a very powerful
way to drive integration tests.

Include `//topaz/public/lib/fuchsia_driver` in your `BUILD.gn` file's deps.

Then make sure to include the following:

```dart
import 'package:fuchsia_driver/fuchsia_driver.dart';
import 'package:flutter_driver/flutter_driver.dart';
```

You can then connect to the Isolate running your mod using the following code:

```dart
final FuchsiaRemoteConnection connection = FuchsiaDriver.connect();
final List<IsolateRef> refs =
    await connection.getMainIsolatesByPattern(yourModulePackageName);
// If this doesn't return null, you can assume there is only one isolate.
final IsolateRef ref = refs.first;
final FlutterDriver driver = await FlutterDriver.connect(
    dartVmServiceUrl: ref.dartVm.uri.toString(),
    isolateNumber: ref.number);
```

Now that you have an instance of the driver, you can drive your mod using the
`FlutterDriver` API.

## Running tests

If you use the Fuchsia Driver for testing, you can either declare your test file
as a `dart_fuchsia_test` target, which will then build your test to run on the
Fuchsia device, or you can make a `dart_remote_test` target in your BUILD.gn
file, which will allow you to run the `flutter_driver` connection from your host
machine to the Fuchsia device through an SSH tunnel.

### Running a `dart_fuchsia_test`

A `dart_fuchsia_test` is a test that runs on the Fuchsia device.

To build one of these tests, first make sure that your test file is under a
`test` folder inside your mod's root directory, and that it ends in
`_test.dart`.

Then, make a `dart_fuchsia_test` target in your BUILD.gn file(imported from
`//build/dart/dart_fuchsia_test.gni`).

You should then point to the target as a package (an example would be
`//topaz/packages/examples/tests` for something that points to a
`dart_fuchsia_test` as one of its package targets.

Then, once you've included this in your build via the `--packages` flag for `fx
set` and installed the package onto your device, you can run it with:

```
$ run your_test_target_name
```

### Running a `dart_remote_test`

A `dart_remote_test` is a test that runs on your host machine that has its env
information (`FUCHSIA_SSH_CONFIG` and `FUCHSIA_DEVICE_URL`) set so that an SSH
tunnel to the Fuchsia device can be created. An example of this would be the
execution of the call
[`FuchsiaRemoteConnection.connect`](https://github.com/flutter/flutter/blob/master/packages/fuchsia_remote_debug_protocol/lib/src/fuchsia_remote_connection.dart#L188),
which uses these environment variables.

Making one of these tests requires that you import
`//build/dart/dart_remote_test.gni` into your BUILD.gn file.

Declaring a `dart_remote_test` target is different from `dart_fuchsia_test` as
you need to specify the source files.

You can then run it using the `fx dart-remote-test` command with a target of
your `GN` target, like
`//topaz/examples/test/driver_example_mod:driver_mod_integration_tests`, for
example.

## Examples

Example code that uses the `flutter_driver`, `fuchsia_driver`,
`dart_fuchsia_test`, and `dart_remote_test` can be found in
`//topaz/examples/test/driver_example_mod`.
