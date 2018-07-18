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
  test('_testLogToSocketWithException', _testLogToSocketWithException);
}

void _testLogToSocketWithException() {
  MockSocket mockSocket = new MockSocket();
  setupLogger(
    name: 'TEST',
    forceShowCodeLocation: false,
    logSocket: mockSocket,
  );
  log.shout('error', new Exception('cause'));

  ByteData byteData = verify(mockSocket.write(captureAny)).captured.single;
  List<int> logged = byteData.buffer.asInt8List(0, byteData.lengthInBytes);
  validateFixedBlock(logged, 3);

  expect(logged[32], equals(4));
  expect(utf8.decode(logged.sublist(33, 37)), equals('TEST'));
  int end = 37;

  // dividing 0 byte
  expect(logged[end++], equals(0));

  int start = end;
  expect(
      utf8.decode(logged.sublist(start)), matches('error: Exception: cause'));
  end = start + 23;
  expect(logged[end++], equals(0));
  expect(logged.length, equals(end));

  mockSocket.close();
}
