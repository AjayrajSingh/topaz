// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// The type of the KV stored in Ledger backing the data
/// stored in Sledge.
/// When modifying this enum:
/// * DO append to the end of the enum.
/// * DO NOT delete entries.
/// * DO NOT re-order entries.
enum KeyValueType {
  /// The type used to identify KVs that store Documents data.
  document
}

/// The length of the prefix storing the Type of data.
const int typePrefixLength = 1;

/// Returns the prefix for the KV storing in Ledger items of type [type].
Uint8List prefixForType(KeyValueType type) {
  assert(type.index >= 0 && type.index <= 255);
  return new Uint8List.fromList([type.index]);
}
