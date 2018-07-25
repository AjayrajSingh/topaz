// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Returns a 20 bytes long hash of [data].
Uint8List hash(Uint8List data) {
  final iterable = sha256.convert(data).bytes.getRange(0, 20);
  return new Uint8List.fromList(new List.from(iterable));
}
