// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// Immutable Key Value pair.
class KeyValue {
  /// Key.
  final Uint8List key;

  /// Value.
  final Uint8List value;

  /// Constructor.
  KeyValue(this.key, this.value);
}
