// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.logging/logging.dart';
import 'package:test/test.dart';

void main() {
  test('_testlogToStdout', _testlogToStdout);
  test('_testLogToStdoutWithError', _testLogToStdoutWithError);
  test('_testLogToStdoutWithLocation', _testLogToStdoutWithLocation);
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
      expect(
          logOutput[0], matches(r'\[INFO:TEST:stdout_test.dart\(\d+\)\] foo'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logOutput.add(line);
      },
    ),
  );
}

void _testLogToStdoutWithError() async {
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
