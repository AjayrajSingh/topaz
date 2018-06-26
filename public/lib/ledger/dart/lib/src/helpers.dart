// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data' show Uint8List;

/// Checks if [keyPrefix] is the prefix of the [key].
/// Both [keyPrefix] and [key] must not be null.
bool hasPrefix(Uint8List key, Uint8List keyPrefix) {
  if (keyPrefix.length > key.length) {
    return false;
  }
  for (int i = 0; i < keyPrefix.length; i++) {
    if (key[i] != keyPrefix[i]) {
      return false;
    }
  }
  return true;
}
