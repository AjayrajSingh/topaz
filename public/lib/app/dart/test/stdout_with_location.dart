// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

const String _fileName = 'stdout_with_location_test.dart';

void main() {
  test('_testLogToStdoutWithLocation', _testLogToStdoutWithLocation);
}

void _testLogToStdoutWithLocation() async {
  final List<String> logOutput = <String>[];
  runZoned<void>(
    () {
      setupLogger(
        name: 'TEST',
        forceShowCodeLocation: true,
      );
      log.info('foo');

      expect(logOutput.length, equals(1));
      expect(logOutput[0], matches('\\[INFO:TEST:$_fileName\\(\\d+\\)\\] foo'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logOutput.add(line);
      },
    ),
  );
}
