// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../document/value.dart';
import '../sledge_connection_id.dart';

/// Class implemented by all the types used in defining schemas.
abstract class BaseType {
  /// Returns the object representing the JSON value of the type.
  /// Called by dart:convert's JsonCodec.
  dynamic toJson();

  /// Returns an object that can hold data described by this type.
  Value newValue(ConnectionId connectionId);
}
