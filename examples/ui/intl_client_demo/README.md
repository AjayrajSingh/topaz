# IntlClientDemo

This is a simple example of a visual mod that is a client of
[`fuchsia.intl.PropertyProvider`](../../../../sdk/fidl/fuchsia.intl/property_provider.fidl),
whose `Locale` can be set at launch and while the mod is running.

`intl_client_demo` renders its view using Skia. Currently, it simply displays
the provided locale ID in a large font in the middle of the view.

## Instructions

1. Build a Fuchsia workstation target with `kitchen_sink`.

    Example:
    ```bash
    $ fx set-petal topaz
    $ fx set workstation.chromebook-x64 --with //bundles:kitchen_sink
    $ fx serve
    ```

2. Boot the device.

3. Start a new session:

    ```bash
    $ fx shell sessionctl login_guest
    ```

4. Launch the module:

    ```bash
    $ fx shell sessionctl add_mod intl_client_demo
    ```
