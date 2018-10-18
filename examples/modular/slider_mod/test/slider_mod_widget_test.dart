// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_remote_debug_protocol/logging.dart';
import 'package:test/test.dart';

void main() {
  FlutterDriver driver;

  // The following boilerplate is a one time setup required to make
  // flutter_driver work in Fuchsia.
  //
  // When a module built using Flutter starts up in debug mode, it creates an
  // instance of the Dart VM, and spawns an Isolate (isolated Dart execution
  // context) containing your module.
  setUpAll(() async {
    // The mod under test
    // const Pattern isolatePattern = 'slider_mod';
    Logger.globalLevel = LoggingLevel.all;
    // Occasionally this will crash if this delay isn't here.
    await new Future<Null>.delayed(const Duration(milliseconds: 500));
    // Creates an object you can use to search for your mod on the machine
    // driver = await FlutterDriver.connect(
    //     fuchsiaModuleTarget: isolatePattern,
    //     printCommunication: true,
    //     logCommunicationToFile: false);
  });

  tearDownAll(() async {
    await driver?.close();
  });

  test(
      'Verify the agent is connected and replies with the correct Fibonacci '
      'result', () async {
    print('hello world!');
    await driver.tap(find.text('Calc Fibonacci'));
    print('after tap');
    await driver.waitFor(find.text('Result: 2'));
    // TODO add the rest of the test here
  }, skip: 're-enable after DX-625 is fixed');
}
