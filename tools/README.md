Modules
=======

> This repository is a workspace and incubator for Fuchsia modules.

# Running Modules

NOTE: On OS X there can be an annoying firewall dialog every time the Magenta tools are rebuilt. To prevent the dialog disable the firewall or sign the new binaries, for instance to sign the `netruncmd`:

    sudo codesign --force --sign - $FUCHSIA_DIR/out/build-magenta/tools/netruncmd

The dialog will now only appear the first time the command is run, at least until it gets rebuilt.

# Debugging

Listen to device logs:

    $FUCHSIA_DIR/out/build-magenta/tools/loglistener

# Configure

Add `config.json` in this directory, it will be ignored by version control.

    # Using make
    make config.json

Then add two values required for OAuth.

    {
      "oauth_id": "<Google APIs client id>"
      "oauth_secret: "<Google APIs client secret>"
    }

To setup Google Image Search for the Image Picker, add these additional values

  {
    "google_search_key": "<Google API key for Custom Search Engine>"
    "google_search_id": "<ID of Custom Search Engine>"
  }

# Authenticate

Once you have the OAuth id and secret it is possible to generate refresh
credentials with:

    make auth

Follow the link in the instructions.

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

    netruncmd : "@boot device_runner"

Running the email story directly

    netruncmd : "@boot device_runner --user_shell=dev_user_shell --user_shell_args=--root_module=email_story"

You can run any top-level module in the same way by replacing `email_story` with
the name of the top-level module.
