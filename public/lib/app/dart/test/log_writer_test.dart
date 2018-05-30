// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

List<String> _tagNames = <String>[
  'TAG1',
  'TAG2',
  'TAG3', // Only 3 global tags are allowed
  'TAG4',
];

List<String> _tooLongTagName = <String>[
  'THIS NAME IS TOO LONG, IT ONLY ALLOWED TO BE 63 CHARACTERS AND NOT 70.',
  // 34567890123456789012345678901234567890123456789012345678901234567890
];

class LoggerStub {
  final List<LogWriterMessage> logMessages = <LogWriterMessage>[];

  void writeLogMessage(LogWriterMessage message) {
    logMessages.add(message);
  }
}

void main() {
  test('simple message', _testSimpleMessage);
  test('constructor options 1', _constructorOptions1);
  test('constructor options 2', _constructorOptions2);
  test('_testTooManyTags', _testTooManyTags);
  test('_tagTooLong', _testTagTooLong);
  test('all levels', _testAllLevels);
  test('default levels', _testDefaultLevels);
}

void _testSimpleMessage() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
  );
  expect(logger.logMessages.isEmpty, true);

  log.info('hello');
  expect(logger.logMessages.length, equals(1));
  expect(logger.logMessages[0].scopeName, equals('main.dart'));
  expect(logger.logMessages[0].tags.isEmpty, equals(true));
  expect(logger.logMessages[0].logRecord.message, equals('hello'));
  expect(logger.logMessages[0].logRecord.level, equals(Level.INFO));
  expect(logger.logMessages[0].logRecord.error, equals(null));
  expect(logger.logMessages[0].logRecord.stackTrace, equals(null));
}

void _constructorOptions1() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
    name: 'LOGGER_NAME',
    level: Level.ALL,
    forceShowCodeLocation: true,
    globalTags: _tagNames.sublist(1, 3),
  );
  expect(logger.logMessages.isEmpty, true);

  log.finest('world');
  expect(logger.logMessages.length, equals(1));
  expect(logger.logMessages[0].scopeName, equals('LOGGER_NAME'));
  expect(
      logger.logMessages[0].codeLocation, startsWith('log_writer_test.dart'));
  expect(logger.logMessages[0].tags.length, equals(2));
  expect(logger.logMessages[0].tags[0], equals(_tagNames[1]));
  expect(logger.logMessages[0].tags[1], equals(_tagNames[2]));
  expect(logger.logMessages[0].logRecord.message, equals('world'));
  expect(logger.logMessages[0].logRecord.level, equals(Level.FINEST));
  expect(logger.logMessages[0].logRecord.error, equals(null));
  expect(logger.logMessages[0].logRecord.stackTrace, equals(null));
}

void _constructorOptions2() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
    level: Level.WARNING,
    forceShowCodeLocation: false,
    globalTags: _tagNames.sublist(0, 3),
  );
  expect(logger.logMessages.isEmpty, true);

  log.warning('cruel');
  expect(logger.logMessages.length, equals(1));
  expect(logger.logMessages[0].codeLocation, equals(null));
  expect(logger.logMessages[0].tags.length, equals(3));
  expect(logger.logMessages[0].tags[0], equals(_tagNames[0]));
  expect(logger.logMessages[0].tags[1], equals(_tagNames[1]));
  expect(logger.logMessages[0].tags[2], equals(_tagNames[2]));
  expect(logger.logMessages[0].logRecord.message, equals('cruel'));
  expect(logger.logMessages[0].logRecord.level, equals(Level.WARNING));

  log.info('info should be blocked because we are at warning level');
  expect(logger.logMessages.length, equals(1));

  log.severe('but sending the higher level severe should get logged');
  expect(logger.logMessages.length, equals(2));
}

void _testTooManyTags() {
  final List<String> stdoutLines = <String>[];
  runZoned<void>(
    () {
      LoggerStub logger = new LoggerStub();
      setupLogger(
        logWriter: logger.writeLogMessage,
        level: Level.WARNING,
        forceShowCodeLocation: false,
        globalTags: _tagNames,
      );
      expect(logger.logMessages.isEmpty, true);

      log.warning('cruel');
      expect(logger.logMessages.length, equals(1));
      expect(logger.logMessages[0].codeLocation, equals(null));
      expect(logger.logMessages[0].tags.length, equals(3));
      expect(logger.logMessages[0].tags[0], equals(_tagNames[0]));
      expect(logger.logMessages[0].tags[1], equals(_tagNames[1]));
      expect(logger.logMessages[0].tags[2], equals(_tagNames[2]));
      expect(logger.logMessages[0].logRecord.message, equals('cruel'));
      expect(logger.logMessages[0].logRecord.level, equals(Level.WARNING));

      expect(stdoutLines.length, equals(2));
      expect(
          stdoutLines[0], equals('WARNING: Logger initialized with > 3 tags.'));
      expect(stdoutLines[1], equals('WARNING: Later tags will be ignored.'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        stdoutLines.add(line);
      },
    ),
  );
}

void _testTagTooLong() {
  final List<String> stdoutLines = <String>[];
  runZoned<void>(
    () {
      LoggerStub logger = new LoggerStub();
      setupLogger(
        logWriter: logger.writeLogMessage,
        level: Level.WARNING,
        forceShowCodeLocation: false,
        globalTags: _tooLongTagName,
      );
      expect(logger.logMessages.isEmpty, true);

      log.warning('cruel');
      expect(logger.logMessages.length, equals(1));
      expect(logger.logMessages[0].codeLocation, equals(null));
      expect(logger.logMessages[0].tags.length, equals(1));
      expect(logger.logMessages[0].tags[0],
          equals(_tooLongTagName[0].substring(0, 63)));
      expect(logger.logMessages[0].logRecord.message, equals('cruel'));
      expect(logger.logMessages[0].logRecord.level, equals(Level.WARNING));

      expect(stdoutLines.length, equals(2));
      expect(stdoutLines[0],
          equals('WARNING: Logger tags limited to 63 characters.'));
      expect(stdoutLines[1], startsWith('WARNING: Tag "'));
    },
    zoneSpecification: new ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        stdoutLines.add(line);
      },
    ),
  );
}

void _testAllLevels() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
    level: Level.ALL,
  );
  expect(logger.logMessages.isEmpty, true);

  log
    ..shout('shout')
    ..severe('severe')
    ..warning('warning')
    ..info('info')
    ..config('config')
    ..fine('fine')
    ..finer('finer')
    ..finest('finest');

  expect(logger.logMessages.length, equals(8));
  expect(logger.logMessages[0].logRecord.message, equals('shout'));
  expect(logger.logMessages[1].logRecord.message, equals('severe'));
  expect(logger.logMessages[2].logRecord.message, equals('warning'));
  expect(logger.logMessages[3].logRecord.message, equals('info'));
  expect(logger.logMessages[4].logRecord.message, equals('config'));
  expect(logger.logMessages[5].logRecord.message, equals('fine'));
  expect(logger.logMessages[6].logRecord.message, equals('finer'));
  expect(logger.logMessages[7].logRecord.message, equals('finest'));
}

void _testDefaultLevels() {
  LoggerStub logger = new LoggerStub();
  setupLogger(
    logWriter: logger.writeLogMessage,
  );
  expect(logger.logMessages.isEmpty, true);

  log
    ..shout('shout')
    ..severe('severe')
    ..warning('warning')
    ..info('info')
    ..config('config')
    ..fine('fine')
    ..finer('finer')
    ..finest('finest');

  expect(logger.logMessages.length, equals(4));
  expect(logger.logMessages[0].logRecord.message, equals('shout'));
  expect(logger.logMessages[1].logRecord.message, equals('severe'));
  expect(logger.logMessages[2].logRecord.message, equals('warning'));
  expect(logger.logMessages[3].logRecord.message, equals('info'));
}
