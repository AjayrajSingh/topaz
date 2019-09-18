// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_modular_testing/fidl_async.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_modular_testing/test.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

const Pattern _isolatePattern = 'driver_example_mod.cmx';
const _testAppUrl =
    'fuchsia-pkg://fuchsia.com/driver_example_mod#meta/driver_example_mod.cmx';

final _addModCommand = modular.AddMod(
    modName: [_isolatePattern],
    modNameTransitional: 'root',
    intent: modular.Intent(action: 'action', handler: _testAppUrl),
    surfaceRelation: modular.SurfaceRelation());

Future<void> _launchModUnderTest(TestHarnessProxy testHarness) async {
  final puppetMaster = modular.PuppetMasterProxy();
  await testHarness.connectToModularService(
      ModularService.withPuppetMaster(puppetMaster.ctrl.request()));

  // Use PuppetMaster to start a fake story and launch the mod under test
  final storyPuppetMaster = modular.StoryPuppetMasterProxy();
  await puppetMaster.controlStory(
      'driver_example_mod_test', storyPuppetMaster.ctrl.request());
  await storyPuppetMaster
      .enqueue([modular.StoryCommand.withAddMod(_addModCommand)]);
  await storyPuppetMaster.execute();
}

void main() {
  group('driver example tests', () {
    TestHarnessProxy testHarness;
    FlutterDriver driver;

    setUpAll(() async {
      testHarness = await launchTestHarness();
      await testHarness.run(TestHarnessSpec(
          envServices:
              EnvironmentServicesSpec(serviceDir: Channel.fromFile('/svc'))));
      await _launchModUnderTest(testHarness);

      driver = await FlutterDriver.connect(
          fuchsiaModuleTarget: _isolatePattern,
          printCommunication: true,
          logCommunicationToFile: false);
    });

    tearDownAll(() async {
      await driver?.close();
      testHarness.ctrl.close();
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
