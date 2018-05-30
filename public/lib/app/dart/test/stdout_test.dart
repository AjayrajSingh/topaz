// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

void main() {
  test('_testlogToStdout', _testlogToStdout);
}

void _testlogToStdout() async {
  final List<String> logOutput = <String>[];
  runZoned<void>(
    () {
      setupLogger(
        name: 'TEST',
        forceShowCodeLocation: false,
      );
      log
        ..info('foo')
        ..warning('bar');

      expect(logOutput.length, equals(2));
      expect(logOutput[0], equals('[INFO:TEST] foo'));
      expect(logOutput[1], equals('[WARNING:TEST] bar'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logOutput.add(line);
      },
    ),
  );
}
