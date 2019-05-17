# ViewConfig demo

This is a simple example of a mod that implements the
[`View` FIDL interface](https://fuchsia.googlesource.com/fuchsia/+/master/sdk/fidl/fuchsia.ui.views/view.fidl)
whose `ViewConfig`, and hence `Locale`, can be set at launch and while the mod
is running.

`view_config_demo` renders its view using Skia. Currently, it simply displays
the provided locale ID in a large font in the middle of the view.

It should not be launched directly from the command line, as that offers no way
to interact with the `View` interface.

The simplest way to launch it is with `present_view` from the Fuchsia shell:

```shell
$ fx shell "present_view \
--locale=en-GB \
fuchsia-pkg://fuchsia.com/view_config_demo#meta/view_config_demo.cmx"
```

You might want to first run `killall scenic.cmx` to ensure that Scenic isn't
already running:

```shell
$ fx shell "killall scenic.cmx; \
present_view --locale=en-GB \
fuchsia-pkg://fuchsia.com/view_config_demo#meta/vw_config_demo.cmx"
```
