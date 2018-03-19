# Updating Flutter

Flutter and many of its dependencies are pinned in Fuchsia.
This file contains instructions for updating Fuchsia's version of Flutter and
its dependencies. The full procedure is often not required to build a stable
system. However, following these instructions will result in a version of
Flutter and its dependencies in Fuchsia that has been built and tested by the
Flutter and Dart teams' CI.

## The Flutter "Triforce"

Updating Fuchsia's version of Flutter requires updating its dependencies. There
are three main components:
  1. [The Flutter framework](https://github.com/flutter/flutter)
  2. [The Flutter engine](https://github.com/flutter/engine)
  3. [The Dart VM](https://github.com/dart-lang/sdk)

## Updating Dart in the engine

Ocassionally, it is necessary to first update the version of the Dart VM used by
the Flutter engine outside of Fuchsia. Instructions for updating the Dart VM in
the Flutter engine are
[here](https://github.com/flutter/engine/wiki/Rolling-Dart).

## Updating the engine in the framework

Updating the version of the Flutter engine used by the Flutter framework outside
of Fuchsia is sometimes needed to trigger Flutter's CI on a more recent version
of the Flutter engine. Instructions for updating the Flutter engine in the
Flutter framework are
[here](https://github.com/flutter/engine/wiki/Release-process).

## Udpating the Flutter "Triforce" in Fuchsia

To roll Flutter forward:
  1. Checkout a new topaz branch:
     ```
     $ git checkout -b roll-flutter-triforce origin/master
     ```
  2. Take the Flutter framework from top-of-tree, and write its hash into the
     `flutter` manifest file in this directory.
  3. Choose the version of the Flutter engine that that version of the Flutter
     framework names under
     [//bin/internal/engine.version](https://github.com/flutter/flutter/blob/master/bin/internal/engine.version)
     and write its hash into the `flutter` manifest file in this directory.
  4. Choose the version of the Dart VM that that version of the Flutter engine
     names in its [DEPS](https://github.com/flutter/engine/blob/master/DEPS)
     file as `dart_revision` and write its hash into the `dart` manifest file
     in this directory.
  5. Update DEFAULT_DART_VERSION in //topaz/tools/download_dev_sdk.py to the
     [current Dart SDK dev version](https://github.com/dart-lang/sdk/commits/dev).
  6. Commit the manifest updates:
     ```
     $ git commit -a -m "[flutter] Rolls the Flutter triforce forward"
     ```
  7. Run the command:
     ```
     $ jiri update -gc --local-manifest=true
     ```

## Updating Dart packages

First, update the Dart packages needed to build the Dart SDK:
  1. Run the commands:
     ```
     $ cd third_party/dart
     $ ./tools/create_pkg_manifest.py -d DEPS -o ../../topaz/manifest/dart_third_party_pkg
     $ ./tools/create_pkg_manifest.py -d DEPS -o ../../topaz/manifest/dart_third_party_pkg_head
     $ cd ../../topaz
     $ git commit -a --amend
     $ cd ..
     ```
  2. Run the command:
     ```
     $ jiri update -gc --local-manifest=true
     ```

Second, update the Dart packages needed by the Flutter framework:
  1. Run the command:
     ```
     $ ./scripts/dart/update_3p_packages.py
     ```
     Dart's pub tool will run and update the Dart package sources under
     `//third_party/dart-pkg/pub`
  2. Create a branch with the package updates:
     ```
     $ cd third_party/dart-pkg/pub
     $ git checkout -b update-3p-pkg origin/master
     $ git commit -a -m "[dart] Update third_party packages"
     ```

## Build Fuchsia and test

Build and test the debug build:
```
$ fx set x86 --goma && fx full-build && fx reboot && fx boot -1
```

Build and test the release build:
```
$ fx set x86 --goma --release && fx full-build && fx reboot && fx boot -1
```

To test the builds:
1. Check that the system boots into the login shell
2. Check that the user shell starts after logging in
3. Check that the build dashboard app starts and displays the build status.

If any of these checks fails, do not continue with the roll. Stop and
investigate.

## Create Roll CLs

Create a CL for updating the topaz manifests
```
$ cd topaz
$ git push origin HEAD:refs/for/master
```
Land this CL first.

Then, create a CL for updating `//third_party/dart-pkg/pub`
```
$ cd third_party/dart-pkg/pub
$ git push origin HEAD:refs/for/master
```
Land this CL second.

# Breaking changes

If a change to a layer below Topaz will break the Dart VM or the Flutter engine,
if at all possible land the updates the the Dart VM and/or the Flutter engine
first. Then, land the breaking changes in the lower layers. This will block
the auto-rollers. Unblock the auto-rollers by landing a manual roll of the
lower layers along with the CL that udpates the Flutter triforce in the Topaz
layer.
