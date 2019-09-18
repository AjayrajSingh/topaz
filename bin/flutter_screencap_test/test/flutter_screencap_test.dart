// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show SplayTreeMap;

import 'package:collection/collection.dart' show SetEquality;
import 'package:test/test.dart';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_modular_session/fidl_async.dart';
import 'package:fidl_fuchsia_modular_testing/fidl_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl_fuchsia_ui_app/fidl_async.dart';
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart';
import 'package:fidl_fuchsia_ui_scenic/fidl_async.dart';
import 'package:fidl_fuchsia_ui_views/fidl_async.dart';
import 'package:fuchsia_modular_testing/test.dart';
import 'package:fuchsia_scenic/views.dart';
import 'package:fuchsia_services/services.dart';
import 'package:pedantic/pedantic.dart';
import 'package:zircon/zircon.dart';

const _testAppUrl =
    'fuchsia-pkg://fuchsia.com/flutter_screencap_test_app#meta/flutter_screencap_test_app.cmx';

final _addModCommand = modular.AddMod(
    modName: ['flutter_screencap_test_app.cmx'],
    modNameTransitional: 'root',
    intent: modular.Intent(action: 'action', handler: _testAppUrl),
    surfaceRelation: modular.SurfaceRelation());

final _ermineConfig = BasemgrConfig(
  sessionShellMap: [
    SessionShellMapEntry(
      name: 'Ermine',
      config: SessionShellConfig(
        appConfig: AppConfig(
          url: 'fuchsia-pkg://fuchsia.com/ermine#meta/ermine.cmx',
        ),
      ),
    ),
  ],
  useSessionShellForStoryShellFactory: true,
);

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

Future<void> _launchModUnderTest(TestHarnessProxy testHarness) async {
  // get the puppetMaster service from the encapsulated test env
  final puppetMaster = modular.PuppetMasterProxy();
  await testHarness.connectToModularService(
      ModularService.withPuppetMaster(puppetMaster.ctrl.request()));

  // use puppetMaster to start a fake story an launch the mod under test
  final storyPuppetMaster = modular.StoryPuppetMasterProxy();
  await puppetMaster.controlStory(
      'flutter_screencap_test', storyPuppetMaster.ctrl.request());
  await storyPuppetMaster
      .enqueue([modular.StoryCommand.withAddMod(_addModCommand)]);
  await storyPuppetMaster.execute();
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

  test('flutter screencap in test shells should have expected top two colors',
      () async {
    final testHarness = await launchTestHarness();

    try {
      await testHarness.run(TestHarnessSpec(
          envServices:
              EnvironmentServicesSpec(serviceDir: Channel.fromFile('/svc'))));
      await _launchModUnderTest(testHarness);

      await _expectTopColors(scenic, _expectedTopTwoColors);
    } finally {
      testHarness.ctrl.close();
    }
  });

  test('flutter screencap as mod in Ermine should have expected top two colors',
      () async {
    final testHarness = await launchTestHarness();

    try {
      await testHarness.run(TestHarnessSpec(
          basemgrConfig: _ermineConfig,
          envServices:
              EnvironmentServicesSpec(serviceDir: Channel.fromFile('/svc'))));
      await _launchModUnderTest(testHarness);

      await _expectTopColors(scenic, _expectedTopTwoColors);
    } finally {
      testHarness.ctrl.close();
    }
  });
}
