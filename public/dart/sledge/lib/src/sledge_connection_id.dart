// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

// TODO: 1. add device ID as a part of connection ID.
// 2. Reuse IDs.

/// Uniquely identify a connection to Ledger,
/// Among all active connections on current device and all possible connections
/// on other devices.
class ConnectionId {
  final Uint8List _id;

  /// Default constructor.
  ConnectionId(this._id);

  /// Creates a completely random conncection ID.
  ConnectionId.random() : _id = new Uint8List(20) {
    final random = new Random(new DateTime.now().microsecondsSinceEpoch);
    for (int i = 0; i < 20; i++) {
      _id[i] = random.nextInt(256);
    }
  }

  /// Returns byte representation of ID.
  Uint8List get id => _id;
}
