Modules
=======

> This repository is a workspace for module exploration and common functionality.

# Module-Specific Instructions

* [Gallery](modules/gallery/README.md)

# Pro-tips

## OS X Firewall Warnings

On OS X there can be an annoying firewall dialog every time the Zircon tools are rebuilt. To prevent the dialog disable the firewall or sign the new binaries, for instance to sign the `netruncmd`:

    sudo codesign --force --sign - $FUCHSIA_DIR/out/build-zircon/tools/netruncmd

The dialog will now only appear the first time the command is run, at least until it gets rebuilt.

## Invalid Certificate Errors

On new or newly provisioned devices it is possible to trigger an SSL error caused by the system clock being set in the future. To prevent this you must set the device clock:

    # On Darwin
    (fgo && DATE=`date +%Y-%m-%dT%T`; ./out/build-zircon/tools/netruncmd : "clock --set $DATE")

    # On Linux
    (fgo && DATE=`date -Iseconds`; ./out/build-zircon/tools/netruncmd : "clock --set $DATE")

This only needs to be done once.

# Logging

Listen to device logs:

    $FUCHSIA_DIR/out/build-zircon/tools/loglistener

# Configuration

Checking out the Fuchsia tree ([instructions][get-started]) will create an
empty `config.json` in this directory. To enable functionality for the modules
living in `//apps/modules/` some values will need to be set.

When the config file is updated a build will be required to load it onto the
target device (see the Build section below).

Various modules require values for:

* chat_firebase_api_key: Firebase API key, used by Chat.
* chat_firebase_project_id: Firebase project ID, used by Chat.
* songkick_api_key: Used by the experimental Music modules.
* spotify_client_id: Used by the experimental Music modules.
* spotify_client_secret: Used by the experimental Music modules.
* google_api_key: Used by prototype modules; YouTube, Maps, ...
* google_search_key: Used by the Gallery for image search.
* google_search_id: Used by the Gallery for image search.
* usps_api_key: Used by the experimental USPS embedded module.

## Authenticate

Email and Chat modules require authenticating with the google apis to function
properly. Make sure to create a new user from the user picker screen, and login
with a test google account in the login UI. This is a one-time process, and once
a user profile is properly created, you can simply select that user later.

Email and Chat modules will not work properly in Guest user mode.

# Build

Make sure to start from a "very clean build" (remove $FUCHSIA_DIR/out) if you have built before but didn't do the auth steps above. There is a make task to help with this:

    make depclean all

This will clean and create a release build. To do this manually you can use:

    source $FUCHSIA_DIR/scripts/env.sh
    rm -rf $FUCHSIA_DIR/out
    fset x86-64 --release --modules default
    fbuild

# Run

Assuming you have an Acer properly networked and running `fboot` in another
terminal session you can run email two different ways.

Running with the full sysui

    netruncmd : "device_runner"

Running the email story directly

    netruncmd : "device_runner --user_shell=dev_user_shell --user_shell_args=--root_module=<target>"

[get-started]: https://fuchsia.googlesource.com/docs/+/master/getting_started.md
