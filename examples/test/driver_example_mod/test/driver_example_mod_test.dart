// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_services/services.dart';
import 'package:test/test.dart';

const Pattern _isolatePattern = 'driver_example_mod.cmx';
const _testAppUrl =
    'fuchsia-pkg://fuchsia.com/driver_example_mod#meta/driver_example_mod.cmx';
const _basemgrUrl = 'fuchsia-pkg://fuchsia.com/basemgr#meta/basemgr.cmx';

// Starts basemgr with dev shells. This should be called from within a
// try/finally or similar construct that closes the component controller.
Future<void> _startBasemgr(
    InterfaceRequest<ComponentController> controllerRequest,
    String rootModUrl) async {
  final context = StartupContext.fromStartupInfo();
  final launcher = LauncherProxy();
  context.incoming.connectToService(launcher);

  final launchInfo = LaunchInfo(url: _basemgrUrl, arguments: [
    '--base_shell=fuchsia-pkg://fuchsia.com/dev_base_shell#meta/dev_base_shell.cmx',
    '--session_shell=fuchsia-pkg://fuchsia.com/dev_session_shell#meta/dev_session_shell.cmx',
    '--session_shell_args=--root_module=$rootModUrl',
    '--story_shell=fuchsia-pkg://fuchsia.com/dev_story_shell#meta/dev_story_shell.cmx',
    '--test',
    '--enable_presenter',
    '--run_base_shell_with_test_runner=false'
  ]);
  await launcher.createComponent(launchInfo, controllerRequest);
  launcher.ctrl.close();
}

void main() {
  group('driver example tests', () {
    final controller = ComponentControllerProxy();
    FlutterDriver driver;

    setUpAll(() async {
      await _startBasemgr(controller.ctrl.request(), _testAppUrl);

      driver = await FlutterDriver.connect(
          fuchsiaModuleTarget: _isolatePattern,
          printCommunication: true,
          logCommunicationToFile: false);
    });

    tearDownAll(() async {
      await driver?.close();
      controller.ctrl.close();
    });

    test('driver connection', () {
      expect(driver, isNotNull);
    });

    test('add to counter. remove from counter', () async {
      await driver.tap(find.text('+1'));
      await driver.tap(find.text('+1'));
      await driver.tap(find.text('+5'));
      await driver.tap(find.text('-1'));
      SerializableFinder textFinder =
          find.text('This counter has a value of: 6');
      // If this value hasn't been set correctly the app will crash, as the
      // widget will not be findable.
      await driver.tap(textFinder);
      await driver.tap(find.text('-5'));
      await driver.tap(find.text('-1'));
      textFinder = find.text('This counter has a value of: 0');
      await driver.tap(textFinder);
    });
  });
}
