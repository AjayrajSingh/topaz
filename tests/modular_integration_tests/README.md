# Topaz Integration Tests

The topaz integration tests use the basemgr to launch a module, then run a
test against said module.

## Adding Tests

This module assumes you've read how to use the flutter and fuchsia driver code,
and have made the appropriate modules to run your own tests:

*   [`flutter_driver` example](https://flutter.io/testing/)

*   [`fuchsia_driver` source and docs](https://fuchsia.googlesource.com/topaz/+/master/public/lib/fuchsia_driver/)

If you'd like to test a module, you'll need to add a dependency in
`packages/tests/modular_integration_tests` (there is an example mod included).

Then, you'll want to target the test(s) in the
`//topaz/tests/modular_integration_tets/topaz_modular_integration_tests.json`
file. The first test target should provide a pretty complete example. Here are
the relevant flags you'll probably want:

*   `--test` should be enabled so that timeouts are possible (this will prevent
    tests from hanging indefinitely).

*   `--enable_presenter` must be set if you wish to draw to the GPU. This is
    required if you wish to simulate touching, scrolling, etc, via
    `flutter_driver`.

*   `--base_shell_args=--test_timeout_ms=[timeout]` This will set the timeout
    for the test. It is recommended to set this to at least 60000 (one minute),
    as in its curret state, the integration testing framework is in its early
    stages and can take a while to complete.

*   `--session_shell_args` These will be broken down based on what they do:

    *   `--root_module` This should almost always be `test_driver_module`, which
        will run you module as well as the testing application.

    *   `--module_under_test_url` This is the URL for the mod you're testing.

    *   `--test_driver_url` This is the URL for the test which will connect to
        the `module_under_test_url` and run integration tests against it. As an
        example: this component will connect to the Dart VM that the module
        under test is running on, then run integration tests, like sending touch
        events or testing specific widgets.

The account provider, base shell, session shell, etc, will likely remain
unchanged except under specific circumstances beyond the scope of this readme.

## Running Tests Manually

After following the above, you can run the integration tests manually by way of
the following command (note that this shouldn't be run on Qemu. It _will_ crash.
The path to this binary is also subject to change.):

```
fx shell /pkgfs/packages/topaz_modular_integration_tests/0/bin/run_topaz_modular_integration_tests.sh
```
