// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

final _random = new Random.secure();

/// Returns a list of random bytes of a given [length].
Uint8List randomUint8List(int length) {
  final result = new Uint8List(length);
  for (int i = 0; i < length; i++) {
    result[i] = _random.nextInt(256);
  }
  return result;
}
