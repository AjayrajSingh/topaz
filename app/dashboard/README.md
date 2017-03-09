# Fuchsia Dashboard

Simple Flutter module to display the Fuchsia build status. This can be built both as an iOS/Android stand-alone Flutter application, or as a module for Fuchsia.

## How to use in a Fuchsia build

1. ```cd $SRC/apps```
2. ```git clone git@github.com:gregsimon/fuchsia_build_status.git dashboard```
3. ```cp $SRC/apps/dashboard/misc_build_files/dashboard $SRC/packages/gn/```
4. Modify ```$SRC/packages/gn/modules``` adding ```"dashboard"``` to the "imports" section:

```

    "labels": [
        "//apps/modules"
    ],
    "imports": [
      "chat",
      "contacts",
      "calendar",
      "dashboard",
      "email"
    ],
    "binaries": [
        { ...
```

5. Build Fuchsia.
6. Run Fuchsia.
7. On the Fuchsia console:
```device_runner --user_shell=dev_user_shell --user_shell_args=--root_module=dashboard```


