// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'uint8list_ops.dart' as utils;

// TODO: 1. add device ID as a part of connection ID.
// 2. Reuse IDs.

/// Uniquely identify a connection to Ledger,
/// Among all active connections on current device and all possible connections
/// on other devices.
class ConnectionId {
  final Uint8List _id;

  /// Default constructor.
  ConnectionId(this._id);

  /// Creates a completely random connection ID.
  ConnectionId.random() : _id = utils.randomUint8List(20);

  /// Returns byte representation of ID.
  Uint8List get id => _id;
}
