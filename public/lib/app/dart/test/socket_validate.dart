// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

const int _lookBackTimeGap = 15 * 1000 * 1000 * 1000; // 15 sec in nanoseconds

const int _zxClockMonotonic = 0;

/// Convert from little endian format bytes to an unsiged 32 bit int.
int bytesToInt32(List<int> bytes) {
  ByteData byteData = new ByteData(4);
  for (int i = 0; i < 4; i++) {
    byteData.setInt8(i, bytes[i]);
  }
  return byteData.getInt32(0, Endian.little);
}

/// Convert from little endian format bytes to an unsiged 64 bit int.
int bytesToUint64(List<int> bytes) {
  ByteData byteData = new ByteData(8);
  for (int i = 0; i < 8; i++) {
    byteData.setInt8(i, bytes[i]);
  }
  return byteData.getUint64(0, Endian.little);
}

/// Validate the primary contents of the fixed location portion of a log
/// record on the logging Socket.
void validateFixedBlock(List<int> data, int level) {
  // Process ID
  expect(bytesToUint64(data), equals(pid));
  // Thread ID
  expect(bytesToUint64(data.sublist(8, 16)), equals(Isolate.current.hashCode));

  // Log time should be within the last 30 seconds
  int nowNanos = Platform.isFuchsia
      ? System.clockGet(_zxClockMonotonic)
      : new DateTime.now().microsecondsSinceEpoch * 1000;
  int logNanos = bytesToUint64(data.sublist(16, 24));
  expect(logNanos, lessThanOrEqualTo(nowNanos));
  expect(logNanos + _lookBackTimeGap, greaterThan(nowNanos));

  expect(bytesToInt32(data.sublist(24, 28)), equals(level));
}
