// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_mod;
import 'package:fuchsia_services/services.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fidl_sys;
import 'package:fuchsia_modular/src/module/internal/_intent_handler_impl.dart';
import 'package:fuchsia_modular_testing/test.dart';
import 'package:fidl_fuchsia_modular_testing/fidl_async.dart';
import 'package:test/test.dart';

const _launcherComponentUrl = 'fuchsia.sys.Launcher';

void main() {
  group('intent handler registration', () {
    TestHarnessProxy harness;

    setUp(() async {
      harness = await launchTestHarness();
    });

    tearDown(() async {
      harness.ctrl.close();
    });

    test('register intent handler registers intent', () async {
      final modUrl = generateComponentUrl();
      final builder = TestHarnessSpecBuilder()..addComponentToIntercept(modUrl);

      final intent = fidl_mod.Intent(action: 'some_action');
      final handledIntentCompleter = Completer<fidl_mod.Intent>();

      // Listen for the module to be launched
      harness.onNewComponent.listen((response) {
        ////////// IN HERMETIC ENVIROMENT OF LAUNCHED COMPONENT ////////////////
        if (response.startupInfo.launchInfo.url != modUrl) {
          return;
        }

        // create a startup context and expose the intent handler
        final context = createStartupContext(response.startupInfo);
        IntentHandlerImpl(startupContext: context).onHandleIntent =
            handledIntentCompleter.complete;
        ////////// END HERMETIC ENVIROMENT OF LAUNCHED COMPONENT ///////////////
      });

      // all setup so run the harness
      await harness.run(builder.build());

      /////////////////// IN HERMETIC ENVIRONMENT OF TEST HARNESS /////////////////
      final incoming = Incoming();
      final launcher = fidl_sys.LauncherProxy();
      final componentControllerProxy = fidl_sys.ComponentControllerProxy();

      // launch the component in the hermetic environment
      await harness.connectToEnvironmentService(
          _launcherComponentUrl, launcher.ctrl.request().passChannel());

      final launchInfo = fidl_sys.LaunchInfo(
          url: modUrl, directoryRequest: incoming.request().passChannel());

      await launcher.createComponent(
          launchInfo, componentControllerProxy.ctrl.request());

      launcher.ctrl.close();

      final intentHandlerProxy = fidl_mod.IntentHandlerProxy();

      // connect to the intent handler service in the hermetic environment
      incoming.connectToService(intentHandlerProxy);
      await intentHandlerProxy.handleIntent(intent);

      await incoming.close();
      componentControllerProxy.ctrl.close();
      /////////////////// END HERMETIC ENVIRONMENT OF TEST HARNESS /////////////////

      // make sure the intent is handled
      final handledIntent = await handledIntentCompleter.future;
      expect(handledIntent.action, intent.action);
    });
  });
}
