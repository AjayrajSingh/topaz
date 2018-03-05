# TODO

> Status: Experimental

This is a Rust backed TODO application that uses Flutter for it's front-end
UI.

* agents:
  * content_provider: Rust based conent provider that stores todos in the Ledger (currently it is only a very simple "hello world" binary).
* modules:
  * story: The top level story UI (Flutter).

# TODO

* [ ] Use Zircon Rust APIs in the content provider.
* [ ] Use Modular Agent APIs in the content provider.
* [ ] Launch the content provider from `todo_story`.
* [ ] Connect the content provider to the Ledger.
* [ ] Create a beautiful UI.

# Development

Make sure to setup a jiri root according to the Fuchsia getting started doc.

## Rust

1. Install rustup.
* Install the latest stable rustc:
* Setup a (temporary) custom clang_wrapper:

    export RUST_TOOLS=${FUCHSIA_DIR}/garnet/public/rust/crates/fuchsia-zircon/tools
    cd $RUST_TOOLS
    clang++ -O --std=c++11 clang_wrapper.cc -o clang_wrapper
    ln -s clang_wrapper x86_64-unknown-fuchsia-cc

## Build

An optional build target for "todo" lives in `//build/gn/todo`. It can be used via `fx set`

    fx set x64 --packages topaz/packages/default,topaz/packages/todo --release

To build the system run:

    # Or use the default `make` task.
    fx full-build

## Run

    # Or use `make run`.
    fx shell "device_runner \
      --device_shell=dev_device_shell \
      --user_shell=dev_user_shell \
      --user_shell_args='--root_module=todo_story'"

## Helpful Tasks

The Makefile includes some common tasks, explore them with `make help`.
