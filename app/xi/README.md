Xi Editor for Fuchsia
=====================

This repository contains the Fuchsia front-end for [xi editor](https://github.com/google/xi-editor).

The back-end, or core (modules/xi-core) is basically the same as for the main
xi editor, except that it is invoked through fidl and uses Zircon sockets for
communication (still using a json-rpc based protocol, though that may evolve
in the future). The front-end is written in Flutter.

> Status: Experimental

What exists here mostly boilerplate for the tooling and infrastructure needed
to build out the UI as a set of Flutter Widgets that can be run on Fuchsia.

# Structure

This repo contains code for running a vanilla [Flutter][flutter] application (iOS & Android) and a [Fuchsia][fuchsia] specific set of [modules][modular].

* **modules**: Fuchsia specific application (module) code.
  * xi-core: Xi core is a Rust binary built with a Fuchsia specific `rustc` (instructions below). A JSON protocol is used to communicate between Xi Core and the Xi UI.
* **packages**: Platform agnostic Dart code separated into [pub packages][pub].
  * widgets: UI code is defined as a set of [Flutter Widgets][widgets-intro] that can be imported and used in either Fuchsia Modules or the vanilla Flutter application.
* **services**: [FIDL][fidl] service definitions.
* **xi_flutter**: A vanilla Flutter application that uses the shared Dart packages and can be run on iOS or Android.

# Development

**NOTE:** Your checkout of Xi ([fuchsia/xi][fuchsia-xi]) needs to be part of the Fuchsia source tree for any of these instructions to work.

## Setup

Follow the instructions for setting up a fresh Fuchsia checkout.  Once you have the `jiri` tool installed and have imported the default manifest and updated return to these instructions.

There is an optional, Rust specific manifest that needs to be added with:

    jiri import rust https://fuchsia.googlesource.com/manifest

Then add/update the Rust projects to your Fuchsia tree with:

    jiri update

## Rust Toolchain

**NOTE:** This step is temporary.

A custom `rustc` build is required before Xi core can be built for Fuchsia. Start by building the [clang wrapper][clang-wrapper] in [fuchsia-zircon][https://fuchsia.googlesource.com/garnet/+/HEAD/public/rust/crates/fuchsia-zircon]:

    export RUST_TOOLS=${FUCHSIA_DIR}/garnet/public/rust/crates/fuchsia-zircon/tools
    cd $RUST_TOOLS
    clang++ -O --std=c++11 clang_wrapper.cc -o clang_wrapper
    ln -s clang_wrapper x86-64-unknown-fuchsia-ar
    ln -s clang_wrapper x86-64-unknown-fuchsia-cc
    ln -s clang_wrapper aarch64-unknown-fuchsia-ar

You can sanity-check the clang wrapper:

    ${RUST_TOOLS}/x86-64-unknown-fuchsia-cc
    clang-4.0: error: no input files

Then clone and build Rust per the [fuchsia-zircon docs][fuchsia-zircon-docs]:

    export RUST_ROOT=${FUCHSIA_DIR}/third_party/rust
    git clone https://github.com/rust-lang/rust.git $RUST_ROOT
    cd $RUST_ROOT

Create a config file:

    cat - <<EOF >$RUST_ROOT/config.toml
    # Config file for fuchsia target for building Rust.
    # See \`src/bootstrap/config.toml.example\` for other settings.

    [rust]
    # Disable backtrace, as it requires additional lib support.
    backtrace = false

    [target.x86_64-unknown-fuchsia]
    cc = "${RUST_TOOLS}/x86-64-unknown-fuchsia-cc"

    [target.aarch64-unknown-fuchsia]
    # Path to the clang wrapper
    cc = "${RUST_TOOLS}/aarch64-unknown-fuchsia-cc"
    EOF

Configure and build rustc (this will take a while):

    ./configure --target=x86_64-unknown-fuchsia
    ./x.py build --stage 1

## Verify Rust Build

Build the zircon examples:

    cd $FUCHSIA_DIR/garnet/public/rust/crates/fuchsia-zircon/

Configure cargo for the fuchsia target:

    mkdir .cargo
    cat - <<EOF >.cargo/config
    [target.x86_64-unknown-fuchsia]
    linker = "${RUST_TOOLS}/x86-64-unknown-fuchsia-cc"
    EOF

Build the fuchsia-zircon example zx_toy:

    RUSTC=${RUST_ROOT}/build/x86_64-apple-darwin/stage1/bin/rustc cargo build --target=x86_64-unknown-fuchsia --example zx_toy

The command above should succeed and generate a rust binary in the target dir.

# Xi

Before the xi-core module can be built the fidl service should be built, this
can be done by commenting out `"//topaz/app/xi/modules",` in the
`topaz/app/xi/BUILD.gn` and then running:

    fx set x64 --packages topaz/packages/default,topaz/packages/xi
    fx full-build

This will error but it will generate the artifacts needed to continue.

Configure xi-core for building with the Fuchsia Rust toolchain. First:

    fgo apps/xi/modules/xi-core
    mkdir .cargo

Then create a configuration file with:

    cat - <<EOF >.cargo/config
    [target.x86_64-unknown-fuchsia]
    linker = "${RUST_TOOLS}/x86-64-unknown-fuchsia-cc"
    EOF

Build the Rust binary for Xi core using the new `rustc`:

    RUSTC=${RUST_ROOT}/build/x86_64-apple-darwin/stage1/bin/rustc cargo build --target=x86_64-unknown-fuchsia

The command above will generate the binary in `target/x86_64-unknown-fuchsia/debug/xi-core`.

# Deploying

First configure your build:

    fx set x64 --packages topaz/packages/default,topaz/packages/xi

Generate and build:

    fx full-build
    scripts/symlink-dot-packages.py --tree=//topaz/app/xi/*

Assuming you have a working Acer setup and are running `fx boot` in a different
terminal session, you can reboot the Acer with the new build using:

    fx reboot

Optional: In another terminal you can tail the logs

    fx log

You can run the zx_toy example from your host with:

    fx shell "example_zx_toy"

You won't see any output, if you run `example_zx_toy` on the device you should see some log output.

To run Xi from your host machine:

    fx shell "bootstrap device_runner --user-shell=dev_user_shell --user-shell-args=--root-module=xi_app"

## Android & Flutter

To run Xi on Android (via the Flutter framework) you will first need to build the `xi-core` binary for the Android target:

    git clone https://github.com/google/xi-editor.git ${FUCHSIA_DIR}/apps/xi-editor
    cd ${FUCHSIA_DIR}/apps/xi-editor/rust
    brew install android-ndk
    export NDK_HOME="$(brew --prefix)/opt/android-ndk"
    ${NDK_HOME}/build/tools/make-standalone-toolchain.sh \
      --platform=android-18 --toolchain=arm-linux-androideabi-clang3.6 \
      --install-dir=android-18-toolchain

Add a config for the android target:

    mkdir .cargo
    cat - <<EOF >.cargo/config
    [build]
    target = "arm-linux-androideabi"

    [target.arm-linux-androideabi]
    linker = "${FUCHSIA_DIR}/apps/xi-editor/rust/android-18-toolchain/bin/clang"
    EOF

Finally, build the binary and push it to a connected Android device:

    cargo build
    adb push target/arm-linux-androideabi/debug/xi-core data/local/tmp/

Run the Flutter app:

    cd ${FUCHSIA_DIR}/apps/xi/xi_flutter
    fx full-build
    ${FUCHSIA_DIR}/scripts/symlink-dot-packages.py --tree=//topaz/app/xi/*
    ${FUCHSIA_DIR}/third_party/dart-pkg/git/flutter/bin/flutter run

[flutter]: https://flutter.io/
[fuchsia]: https://fuchsia.googlesource.com/fuchsia/
[modular]: https://fuchsia.googlesource.com/modular/
[pub]: https://www.dartlang.org/tools/pub/get-started
[dart]: https://www.dartlang.org/
[fidl]: https://fuchsia.googlesource.com/fidl/
[widgets-intro]: https://flutter.io/widgets-intro/
[fuchsia-setup]: https://fuchsia.googlesource.com/fuchsia/+/HEAD/README.md
[fuchsia-env]: https://fuchsia.googlesource.com/fuchsia/+/HEAD/README.md#Setup-Build-Environment
[clang-wrapper]: https://fuchsia.googlesource.com/garnet/+/HEAD/public/rust/crates/fuchsia-zircon/tools
[fuchsia-zircon-docs]: https://fuchsia.googlesource.com/garnet/+/HEAD/public/rust/crates/fuchsia-zircon/GETTING_STARTED.md
[fuchsia-xi]: https://fuchsia.googlesource.com/xi/
