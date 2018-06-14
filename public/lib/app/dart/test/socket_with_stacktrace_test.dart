// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:lib.app.dart/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

import 'socket_validate.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  test('_testLogToSocketWithStacktrace', _testLogToSocketWithStacktrace);
}

const int _socketBufferLength = 2032;
const String _errorMsg = 'this error message plus the stacktrace need to be '
    'long enough to hit the max block size to validate that truncation of long '
    'messages works properly';

void _testLogToSocketWithStacktrace() {
  MockSocket mockSocket = new MockSocket();
  setupLogger(
    name: 'TEST',
    forceShowCodeLocation: false,
    logSocket: mockSocket,
  );
  log.severe(_errorMsg, new Exception('because'), StackTrace.current);

  ByteData byteData = verify(mockSocket.write(captureAny)).captured.single;
  List<int> logged = byteData.buffer.asInt8List(0, byteData.lengthInBytes);
  validateFixedBlock(logged, Level.SEVERE);

  expect(logged[32], equals(4));
  expect(utf8.decode(logged.sublist(33, 37)), equals('TEST'));
  int end = 37;

  // dividing 0 byte
  expect(logged[end++], equals(0));

  String msg = utf8.decode(logged.sublist(end));
  expect(msg, startsWith('$_errorMsg: Exception: because\n'));
  expect(msg, matches(r'.*_testLogToSocketWithStacktrace'));
  expect(logged.length, equals(_socketBufferLength));
  expect(
      utf8.decode(
          logged.sublist(_socketBufferLength - 4, _socketBufferLength - 1)),
      equals('...'));

  mockSocket.close();
}
