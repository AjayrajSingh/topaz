// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

/// Convert from little endian format bytes to an integer of specified length.
int bytesToInt(List<int> bytes, int byteCount) {
  int result = 0;
  for (int i = 0; i < byteCount; i++) {
    int byte = bytes[i] >= 0 ? bytes[i] : 256 + bytes[i];
    result += byte << (8 * i);
  }
  return result;
}

/// Validate the primary contents of the fixed location portion of a log
/// record on the logging Socket.
void validateFixedBlock(List<int> data, Level level) {
  // Process ID
  expect(bytesToInt(data, 8), equals(pid));
  // Thread ID
  expect(bytesToInt(data.sublist(8, 16), 8), equals(Isolate.current.hashCode));

  // Log time should be within the last 30 seconds
  int nowMicros = new DateTime.now().microsecondsSinceEpoch;
  int logMicros = bytesToInt(data.sublist(16, 24), 8);
  expect(logMicros, lessThanOrEqualTo(nowMicros));
  expect(logMicros + 30000000, greaterThan(nowMicros));

  expect(bytesToInt(data.sublist(24, 28), 4), equals(level.value));
}
