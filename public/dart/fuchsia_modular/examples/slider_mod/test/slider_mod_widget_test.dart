// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular_testing/fidl_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_remote_debug_protocol/logging.dart';
import 'package:fuchsia_services/services.dart';
import 'package:test/test.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart';

const Pattern _isolatePattern = 'slider_mod.cmx';
const _testAppUrl = 'fuchsia-pkg://fuchsia.com/slider_mod#meta/slider_mod.cmx';
const _modularTestHarnessURL =
    'fuchsia-pkg://fuchsia.com/modular_test_harness#meta/modular_test_harness.cmx';

TestHarnessProxy testHarnessProxy = TestHarnessProxy();
ComponentControllerProxy testHarnessController = ComponentControllerProxy();

// Starts Modular TestHarness with dev shells. This should be called from within
// a try/finally or similar construct that closes the component controller.
Future<void> _startTestHarness() async {
  final launcher = LauncherProxy();
  final incoming = Incoming();

  // launch TestHarness component
  StartupContext.fromStartupInfo().incoming.connectToService(launcher);
  await launcher.createComponent(
      LaunchInfo(
          url: _modularTestHarnessURL,
          directoryRequest: incoming.request().passChannel()),
      testHarnessController.ctrl.request());

  // connect to TestHarness service
  incoming.connectToService(testHarnessProxy);

  // helper function to convert a map of service to url into list of
  // [InjectedService]
  List<InjectedService> _toInjectedServices(Map<String, String> serviceToUrl) {
    final injectedServices = <InjectedService>[];
    for (final svcName in serviceToUrl.keys) {
      injectedServices
          .add(InjectedService(name: svcName, url: serviceToUrl[svcName]));
    }
    return injectedServices;
  }

  final testHarnessSpec = TestHarnessSpec(
      envServicesToInherit: ['fuchsia.net.SocketProvider'],
      envServicesToInject: _toInjectedServices(
        {
          'fuchsia.auth.account.AccountManager':
              'fuchsia-pkg://fuchsia.com/account_manager#meta/account_manager.cmx',
          'fuchsia.devicesettings.DeviceSettingsManager':
              'fuchsia-pkg://fuchsia.com/device_settings_manager#meta/device_settings_manager.cmx',
          'fuchsia.fonts.Provider':
              'fuchsia-pkg://fuchsia.com/fonts#meta/fonts.cmx',
          'fuchsia.sysmem.Allocator':
              'fuchsia-pkg://fuchsia.com/sysmem_connector#meta/sysmem_connector.cmx',
          'fuchsia.tracelink.Registry':
              'fuchsia-pkg://fuchsia.com/trace_manager#meta/trace_manager.cmx',
          'fuchsia.ui.input.ImeService':
              'fuchsia-pkg://fuchsia.com/ime_service#meta/ime_service.cmx',
          'fuchsia.ui.policy.Presenter':
              'fuchsia-pkg://fuchsia.com/root_presenter#meta/root_presenter.cmx',
          'fuchsia.ui.scenic.Scenic':
              'fuchsia-pkg://fuchsia.com/scenic#meta/scenic.cmx',
          'fuchsia.vulkan.loader.Loader':
              'fuchsia-pkg://fuchsia.com/vulkan_loader#meta/vulkan_loader.cmx'
        },
      ));

  // run the test harness which will create an encapsulated test env
  await testHarnessProxy.run(testHarnessSpec);
}

Future<void> _launchModUnderTest() async {
  // get the puppetMaster service from the encapsulated test env
  final puppetMasterProxy = PuppetMasterProxy();
  await testHarnessProxy.connectToModularService(
      ModularService.withPuppetMaster(puppetMasterProxy.ctrl.request()));
  // use puppetMaster to start a fake story an launch the mod under test
  final storyPuppetMasterProxy = StoryPuppetMasterProxy();
  await puppetMasterProxy.controlStory(
      'fooStoryName', storyPuppetMasterProxy.ctrl.request());
  await storyPuppetMasterProxy.enqueue(<StoryCommand>[
    StoryCommand.withAddMod(AddMod(
        modName: ['slider_mod'],
        modNameTransitional: 'root',
        intent: Intent(action: 'action', handler: _testAppUrl),
        surfaceRelation: SurfaceRelation()))
  ]);
  await storyPuppetMasterProxy.execute();
}

@Timeout(Duration(seconds: 10))
void main() {
  final controller = ComponentControllerProxy();
  FlutterDriver driver;

  // The following boilerplate is a one time setup required to make
  // flutter_driver work in Fuchsia.
  //
  // When a module built using Flutter starts up in debug mode, it creates an
  // instance of the Dart VM, and spawns an Isolate (isolated Dart execution
  // context) containing your module.
  setUpAll(() async {
    Logger.globalLevel = LoggingLevel.all;

    await _startTestHarness();
    await _launchModUnderTest();

    // Creates an object you can use to search for your mod on the machine
    driver = await FlutterDriver.connect(
        fuchsiaModuleTarget: _isolatePattern,
        printCommunication: true,
        logCommunicationToFile: false);
  });

  tearDownAll(() async {
    await driver?.close();
    controller.ctrl.close();

    testHarnessProxy.ctrl.close();
    testHarnessController.ctrl.close();
  });

  test(
      'Verify the agent is connected and replies with the correct Fibonacci '
      'result', () async {
    print('tapping on Calc Fibonacci button');
    await driver.tap(find.text('Calc Fibonacci'));
    print('verifying the result');
    await driver.waitFor(find.byValueKey('fib-result-widget-key'));
    print('test is finished successfully');
  });
}
