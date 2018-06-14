// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:lib.app.dart/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

import 'legacy_code.dart';
import 'socket_validate.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  test('_testLegacyLogger', _testLegacyLogger);
}

void _testLegacyLogger() {
  MockSocket mockSocket = new MockSocket();
  setupLogger(
    name: 'TEST',
    forceShowCodeLocation: false,
    logSocket: mockSocket,
  );

  makeOneLegacyLogCall();

  ByteData byteData = verify(mockSocket.write(captureAny)).captured.single;
  List<int> logged = byteData.buffer.asInt8List(0, byteData.lengthInBytes);
  validateFixedBlock(logged, Level.INFO);
  expect(logged[32], equals(4));
  expect(utf8.decode(logged.sublist(33, 37)), equals('TEST'));
  expect(utf8.decode(logged.sublist(38, 43)), equals('hello'));
  expect(logged[43], equals(0));
  // Length should be 33 + 5 (TEST) + 6 (foo)
  expect(logged.length, equals(44));

  mockSocket.close();
}
