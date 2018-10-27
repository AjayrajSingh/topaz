// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_remote_debug_protocol/logging.dart';
import 'package:fidl_fuchsia_testing_runner/fidl_async.dart';
import 'package:fuchsia/services.dart';
import 'package:test/test.dart';

void main() {
  FlutterDriver driver;
  TestRunnerProxy testRunner;
  // The following boilerplate is a one time setup required to make
  // flutter_driver work in Fuchsia.
  //
  // When a module built using Flutter starts up in debug mode, it creates an
  // instance of the Dart VM, and spawns an Isolate (isolated Dart execution
  // context) containing your module.
  setUpAll(() async {
    // Connect to the fuchsia test runner
    testRunner = new TestRunnerProxy();
    connectToEnvironmentService(testRunner);

    // The mod under test
    const Pattern isolatePattern = 'slider_mod';
    Logger.globalLevel = LoggingLevel.all;
    // Occasionally this will crash if this delay isn't here.
    await new Future<Null>.delayed(const Duration(milliseconds: 500));
    // Creates an object you can use to search for your mod on the machine
    driver = await FlutterDriver.connect(
        fuchsiaModuleTarget: isolatePattern,
        printCommunication: true,
        logCommunicationToFile: false);
  });

  tearDownAll(() async {
    await driver?.close();
    // Must be invoked before closing the connection to this interface;
    // otherwise the TestRunner service will assume that the connection broke
    // due to the test crashing.
    await testRunner.done();
  });

  test(
      'Verify the agent is connected and replies with the correct Fibonacci '
      'result', () async {
    print('tapping on Calc Fibonacci button');
    await driver.tap(find.text('Calc Fibonacci'));
    print('verifying the result');
    await driver.waitFor(find.text('Result: 2'));
    print('test is finished successfully');
  });
}
