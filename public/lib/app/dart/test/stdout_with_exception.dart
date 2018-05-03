// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

void main() {
  test('_testLogToStdoutWithException', _testLogToStdoutWithException);
}

void _testLogToStdoutWithException() async {
  final List<String> logOutput = <String>[];
  runZoned<void>(
    () {
      setupLogger(
        name: 'TEST',
        level: Level.ALL,
        forceShowCodeLocation: false,
      );
      log.shout('foo', new Exception('cause'));

      expect(logOutput.length, equals(1));
      expect(logOutput[0], equals('[FATAL:TEST] foo: Exception: cause'));

      log.severe('bar', new Exception('because'), StackTrace.current);

      expect(logOutput.length, equals(3));
      expect(logOutput[1], equals('[ERROR:TEST] bar: Exception: because'));
      expect(logOutput[2], matches(r'.*_testLogToStdoutWithError.*'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logOutput.add(line);
      },
    ),
  );
}
