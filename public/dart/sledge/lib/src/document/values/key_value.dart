// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// Immutable Key Value pair.
class KeyValue {
  /// Key.
  final ByteData key;

  /// Value.
  final ByteData value;

  /// Constructor.
  KeyValue(this.key, this.value);
}
