// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// Concatenate two byte arrays.
Uint8List concatUint8Lists(Uint8List a, Uint8List b) {
  return new Uint8List(a.length + b.length)..setAll(0, a)..setAll(a.length, b);
}

/// Returns the prefix of [x] of length [prefixLen].
Uint8List getUint8ListPrefix(Uint8List x, int prefixLen) {
  return new Uint8List(prefixLen)..setAll(0, x.getRange(0, prefixLen));
}

/// Returns the suffix of [x] starting from [prefixLen].
Uint8List getUint8ListSuffix(Uint8List x, int prefixLen) {
  return new Uint8List(x.length - prefixLen)
    ..setAll(0, x.getRange(prefixLen, x.length));
}
