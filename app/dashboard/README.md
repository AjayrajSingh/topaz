# Fuchsia Build Status Dashboard

Simple Flutter module to display the Fuchsia build status. This can be built both as an iOS/Android stand-alone Flutter application, or as a module for Fuchsia.

## How to use in a Fuchsia build as a Module

1. ```cd $SRC/apps```
2. ```git clone git@github.com:gregsimon/fuchsia_build_status.git ```
3. ```cp $SRC/third_party/fuchsia_build_status/misc_build_files/fuchsia_build_status $SRC/packages/gn/```
4. Modify ```$SRC/packages/gn/default``` adding ```"fuchsia_build_status"``` to the "imports" section:

```

    "imports": [
      "fonts",
      "fortune",
      "ftl",
      "fuchsia_build_status",
      "gdb_server",
```

5. Build Fuchsia.
6. Run Fuchsia.
7. On the Fuchsia console:
```device_runner --user_shell=dev_user_shell --user_shell_args=--root_module=fuchsia_build_status```


## How to self-boot into the dashboard

1. ```cp $SRC/third_party/fuchsia_build_status/misc_build_files/boot_dashboard $SRC/packages/gn/```

2. packages/gn/gen.py -m boot_dashboard


## How to build for iOS, Android

1. ```cd $SRC```
2. ```flutter run```
