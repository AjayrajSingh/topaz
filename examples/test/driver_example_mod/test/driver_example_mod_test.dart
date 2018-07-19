// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:fuchsia_driver/fuchsia_driver.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_remote_debug_protocol/fuchsia_remote_debug_protocol.dart';
import 'package:fuchsia_remote_debug_protocol/logging.dart';
import 'package:test/test.dart';

void main() {
  group('driver example tests', () {
    FlutterDriver driver;
    FuchsiaRemoteConnection connection;

    setUpAll(() async {
      Logger.globalLevel = LoggingLevel.all;
      connection = await FuchsiaDriver.connect();
      const Pattern isolatePattern = 'driver_example_mod_wrapper';
      print('Finding $isolatePattern');
      final List<IsolateRef> refs =
          await connection.getMainIsolatesByPattern(isolatePattern);
      final IsolateRef ref = refs.first;
      // Occasionally this will crash if this delay isn't here.
      await new Future<Null>.delayed(const Duration(milliseconds: 500));
      driver = await FlutterDriver.connect(
          dartVmServiceUrl: ref.dartVm.uri.toString(),
          isolateNumber: ref.number,
          printCommunication: true,
          logCommunicationToFile: false);
    });

    tearDownAll(() async {
      if (driver != null) {
        await driver.close();
      }
      if (connection != null) {
        await connection.stop();
      }
      await FuchsiaDriver.cleanup();
    });

    test('add to counter. remove from counter', () async {
      await driver.tap(find.text('+1'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      await driver.tap(find.text('+1'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      await driver.tap(find.text('+5'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      await driver.tap(find.text('-1'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      SerializableFinder textFinder =
          find.text('This counter has a value of: 6');
      // If this value hasn't been set correctly the app will crash, as the
      // widget will not be findable.
      await driver.tap(textFinder);
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      await driver.tap(find.text('-5'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      await driver.tap(find.text('-1'));
      await new Future<Null>.delayed(const Duration(milliseconds: 200));
      textFinder = find.text('This counter has a value of: 0');
      await driver.tap(textFinder);
    });
  });
}
