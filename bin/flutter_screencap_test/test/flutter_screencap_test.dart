// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show SplayTreeMap;
import 'dart:io';

import 'package:collection/collection.dart' show SetEquality;
import 'package:test/test.dart';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl_fuchsia_ui_app/fidl_async.dart';
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart';
import 'package:fidl_fuchsia_ui_scenic/fidl_async.dart';
import 'package:fidl_fuchsia_ui_views/fidl_async.dart';
import 'package:fuchsia_scenic/views.dart';
import 'package:fuchsia_services/services.dart';
import 'package:pedantic/pedantic.dart';

const _testAppUrl =
    'fuchsia-pkg://fuchsia.com/flutter_screencap_test_app#meta/flutter_screencap_test_app.cmx';
const _basemgrUrl = 'fuchsia-pkg://fuchsia.com/basemgr#meta/basemgr.cmx';
const _ermineUrl = 'fuchsia-pkg://fuchsia.com/ermine#meta/ermine.cmx';

// Use a custom timeout rather than the test framework's timeout so that we can
// output a sensible failure message.
final Duration _timeout = Duration(seconds: 15);

const int _blankColor = 0x00000000;
// See lib/main.dart.
final Set<int> _expectedTopTwoColors = {0xFF4dac26, 0xFFd01c8b};

ViewToken _createPresentationViewToken() {
  final tokenPair = ViewTokenPair();
  final presenter = PresenterProxy();

  try {
    StartupContext.fromStartupInfo().incoming.connectToService(presenter);
    presenter.presentView(tokenPair.viewHolderToken, null);
    return tokenPair.viewToken;
  } finally {
    presenter.ctrl.close();
  }
}

Future<bool> _screenshotUntil(ScenicProxy scenic,
    bool Function(Scenic$TakeScreenshot$Response) condition) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < _timeout) {
    if (condition(await scenic.takeScreenshot().timeout(_timeout))) {
      return true;
    }
  }
  return false;
}

int _argbFromBgra(List<int> bgra) {
  return bgra[0] | bgra[1] << 8 | bgra[2] << 16 | bgra[3] << 24;
}

// Produces a map of 32-bit ARGB colors to pixel counts.
Map<int, int> _computeHistogram(ScreenshotData screenshot) {
  final bytes = screenshot.data.vmo.map();

  final Map<int, int> histogram = {};

  for (int i = 0; i < screenshot.data.size; i += 4) {
    // Convert from BGRA to ARGB for consistency with Flutter.
    final color = _argbFromBgra(bytes.sublist(i, i + 4));
    histogram[color] = (histogram[color] ?? 0) + 1;
  }

  return histogram;
}

// Produces a sorted map of pixel counts to 32-bit ARGB colors.
SplayTreeMap<int, Set<int>> _invertHistogram(Map<int, int> histogram) {
  final sortedHistogram =
      SplayTreeMap<int, Set<int>>((count1, count2) => count2.compareTo(count1));

  for (final entry in histogram.entries) {
    sortedHistogram.putIfAbsent(entry.value, () => {}).add(entry.key);
  }

  return sortedHistogram;
}

// Displays the test app using root presenter. This should be called from
// within a try/finally or similar construct that closes the component
// controller.
Future<void> _startAppAsRootView(
    InterfaceRequest<ComponentController> controllerRequest) async {
  final context = StartupContext.fromStartupInfo();

  final incoming = Incoming();
  final launchInfo = LaunchInfo(
      url: _testAppUrl, directoryRequest: incoming.request().passChannel());
  final launcher = LauncherProxy();
  context.incoming.connectToService(launcher);
  await launcher.createComponent(launchInfo, controllerRequest);
  launcher.ctrl.close();

  final viewProvider = ViewProviderProxy();
  try {
    incoming.connectToService(viewProvider);
    await viewProvider.createView(
        _createPresentationViewToken().value, null, null);
  } finally {
    viewProvider.ctrl.close();
    unawaited(incoming.close());
  }
}

// Starts basemgr with dev shells. This should be called from within a
// try/finally or similar construct that closes the component controller.
Future<void> _startDevBasemgr(
    InterfaceRequest<ComponentController> controllerRequest) async {
  final context = StartupContext.fromStartupInfo();

  final launchInfo = LaunchInfo(url: _basemgrUrl, arguments: [
    '--base_shell=fuchsia-pkg://fuchsia.com/dev_base_shell#meta/dev_base_shell.cmx',
    '--session_shell=fuchsia-pkg://fuchsia.com/dev_session_shell#meta/dev_session_shell.cmx',
    '--session_shell_args=--root_module=$_testAppUrl',
    '--story_shell=fuchsia-pkg://fuchsia.com/dev_story_shell#meta/dev_story_shell.cmx',
    '--test',
    '--enable_presenter',
    '--run_base_shell_with_test_runner=false'
  ]);
  final launcher = LauncherProxy();
  context.incoming.connectToService(launcher);
  await launcher.createComponent(launchInfo, controllerRequest);
  launcher.ctrl.close();
}

// Starts the basemgr configured to launch the Ermine session shell. This
// should be called from within a try/finally or similar construct that closes
// the component controller.
Future<void> _startErmine(
    InterfaceRequest<ComponentController> controllerRequest) async {
  final context = StartupContext.fromStartupInfo();

  final launchInfo =
      LaunchInfo(url: _basemgrUrl, arguments: ['--session_shell=$_ermineUrl']);
  final launcher = LauncherProxy();
  context.incoming.connectToService(launcher);
  await launcher.createComponent(launchInfo, controllerRequest);
  launcher.ctrl.close();
}

// Blank can manifest as invalid screenshots or blackness.
Future<bool> _waitForBlank(ScenicProxy scenic) {
  return _screenshotUntil(scenic, (response) {
    if (!response.success) {
      return true;
    } else {
      final histogram = _computeHistogram(response.imgData);
      return histogram.isEmpty ||
          histogram.length == 1 && histogram.keys.single == _blankColor;
    }
  });
}

// Verifies that the top colors displayed on the screen are the [expected] set
// of 32-bit ARGB colors.
Future<void> _expectTopColors(ScenicProxy scenic, Set<int> expected) async {
  final Set<int> topColors = {};

  await _screenshotUntil(scenic, (response) {
    if (!response.success) {
      return false;
    }

    topColors.clear();
    // reduce while; takeWhile is lazy but reduce doesn't short circuit.
    _invertHistogram(_computeHistogram(response.imgData))
        .values
        .takeWhile(
            (colors) => (topColors..addAll(colors)).length < expected.length)
        .length; // Evaluate length to force the lazy evaluation.

    return SetEquality().equals(topColors, expected);
  });

  expect(topColors, expected);
}

void main() {
  final scenic = ScenicProxy();

  setUpAll(
      () => StartupContext.fromStartupInfo().incoming.connectToService(scenic));
  tearDownAll(scenic.ctrl.close);

  setUp(() => _waitForBlank(scenic));

  // This test uses root presenter to display the flutter screencap test app.
  test('flutter screencap as root view should have expected top two colors',
      () async {
    final controller = ComponentControllerProxy();

    try {
      await _startAppAsRootView(controller.ctrl.request());
      await _expectTopColors(scenic, _expectedTopTwoColors);
    } finally {
      controller.ctrl.close();
    }
  });

  test(
      'flutter screencap as root mod in dev shells should have expected top two colors',
      () async {
    final controller = ComponentControllerProxy();

    try {
      await _startDevBasemgr(controller.ctrl.request());
      await _expectTopColors(scenic, _expectedTopTwoColors);
    } finally {
      controller.ctrl.close();
    }
  });

  // This test starts Ermine session shell and uses sessionctl to add the
  // flutter screencap test app.
  test('flutter screencap as mod in Ermine should have expected top two colors',
      () async {
    final controller = ComponentControllerProxy();

    try {
      await _startErmine(controller.ctrl.request());
      // sessionctl uses the basemgr debug service exposed on the /hub.
      await controller.onDirectoryReady.first;
      final ProcessResult result =
          await Process.run('/bin/sessionctl', ['add_mod', _testAppUrl]);
      print(result.stdout);
      expect(result.exitCode, 0, reason: result.stderr);
      await _expectTopColors(scenic, _expectedTopTwoColors);
    } finally {
      controller.ctrl.close();
    }
  });
}
