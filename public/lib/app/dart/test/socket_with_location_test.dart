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

const String _fileName = 'socket_with_location_test.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  test('_testLogToSocketWithLocation', _testLogToSocketWithLocation);
}

void _testLogToSocketWithLocation() {
  MockSocket mockSocket = new MockSocket();
  setupLogger(
    name: 'TEST',
    level: Level.ALL,
    forceShowCodeLocation: true,
    logSocket: mockSocket,
  );
  log.finest('bar');

  ByteData byteData = verify(mockSocket.write(captureAny)).captured.single;
  List<int> logged = byteData.buffer.asInt8List(0, byteData.lengthInBytes);
  validateFixedBlock(logged, Level.FINEST);

  expect(logged[32], equals(4));
  expect(utf8.decode(logged.sublist(33, 37)), equals('TEST'));
  int start = 37;
  expect(logged[start], greaterThan(_fileName.length));
  int end = start + logged[start] + 1;
  start++;
  expect(
      utf8.decode(logged.sublist(start, end)), matches('$_fileName\\(\\d+\\)'));

  // dividing 0 byte
  expect(logged[end++], equals(0));

  start = end;
  expect(utf8.decode(logged.sublist(start, start + 3)), equals('bar'));
  end = start + 3;
  expect(logged[end++], equals(0));
  expect(logged.length, equals(end));

  mockSocket.close();
}
