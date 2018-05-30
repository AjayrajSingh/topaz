// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

const int _lookBackTimeGap = 15 * 1000 * 1000 * 1000; // 15 sec in nanoseconds

const int _zxClockMonotonic = 0;

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
  int nowNanos = Platform.isFuchsia
      ? System.clockGet(_zxClockMonotonic)
      : new DateTime.now().microsecondsSinceEpoch * 1000;
  int logNanos = bytesToInt(data.sublist(16, 24), 8);
  expect(logNanos, lessThanOrEqualTo(nowNanos));
  expect(logNanos + _lookBackTimeGap, greaterThan(nowNanos));

  expect(bytesToInt(data.sublist(24, 28), 4), equals(level.value));
}
