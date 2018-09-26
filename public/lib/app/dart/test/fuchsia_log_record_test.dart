// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

import 'package:lib.app.dart/logging.dart';
import 'package:lib.app.dart/src/fuchsia_log_record.dart';

const int _lookBackTimeGap = 15 * 1000 * 1000 * 1000; // 15 sec in nanoseconds

const int _zxClockMonotonic = 0;

class LoggerStub {
  final List<LogWriterMessage> logMessages = <LogWriterMessage>[];

  void writeLogMessage(LogWriterMessage message) {
    logMessages.add(message);
  }
}

void main() {
  test('simple message', _testSimpleMessage);
  test('message with exception', _testMessageWithException);
}

void _testSimpleMessage() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
  );
  expect(logger.logMessages.isEmpty, true);

  log.infoT('hello', tag: 'tag');
  expect(logger.logMessages.length, equals(1));
  FuchsiaLogRecord underTest = logger.logMessages[0].logRecord;

  int now = Platform.isFuchsia
      ? System.clockGet(_zxClockMonotonic)
      : new DateTime.now().microsecondsSinceEpoch * 1000;

  expect(underTest.systemTime, lessThanOrEqualTo(now));
  expect(underTest.systemTime, greaterThanOrEqualTo(now - _lookBackTimeGap));

  expect(underTest.localTag, equals('tag'));
  expect(underTest.level, equals(Level.INFO));
  expect(underTest.message, equals('hello'));
  expect(underTest.sequenceNumber, equals(1));
  expect(underTest.error, equals(null));
  expect(underTest.stackTrace, equals(null));

  log.info('world');
  expect(logger.logMessages.length, equals(2));
  underTest = logger.logMessages[1].logRecord;
  expect(underTest.sequenceNumber, equals(2));
}

void _testMessageWithException() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
  );
  expect(logger.logMessages.isEmpty, true);

  Exception exception = new Exception('cause');
  log.infoT('hello',
      tag: 'tag', error: exception, stackTrace: StackTrace.current);
  expect(logger.logMessages.length, equals(1));
  FuchsiaLogRecord underTest = logger.logMessages[0].logRecord;

  int now = Platform.isFuchsia
      ? System.clockGet(_zxClockMonotonic)
      : new DateTime.now().microsecondsSinceEpoch * 1000;

  expect(underTest.systemTime, lessThanOrEqualTo(now));
  expect(underTest.systemTime, greaterThanOrEqualTo(now - _lookBackTimeGap));

  expect(underTest.localTag, equals('tag'));
  expect(underTest.level, equals(Level.INFO));
  expect(underTest.message, equals('hello'));
  expect(underTest.error, equals(exception));
  expect(
      underTest.stackTrace.toString(), contains('_testMessageWithException'));
}
