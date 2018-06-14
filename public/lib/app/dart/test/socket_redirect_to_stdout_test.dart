// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This test should run on device to enable sys_logger

import 'dart:async';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

void main() {
  test('_testlogToStdout', _testlogToStdout);
}

void _testlogToStdout() {
  final List<String> logOutput = <String>[];
  runZoned<void>(
    () {
      setupLogger(
        name: 'TEST',
        forceShowCodeLocation: false,
        logToStdoutForTest: true,
      );
      log.info('foo');

      expect(logOutput.length, equals(1));
      expect(logOutput[0], equals('[INFO:TEST] foo'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logOutput.add(line);
      },
    ),
  );
}
