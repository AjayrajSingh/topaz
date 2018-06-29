// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

class Entry {
  final bool isDeleted;
  final Uint8List value;
  final int timestamp;

  Entry(this.value, this.timestamp) : isDeleted = false;

  Entry.deleted(this.timestamp)
      : value = null,
        isDeleted = true;
}
