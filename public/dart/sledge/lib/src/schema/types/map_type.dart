// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../../document/value.dart';
import '../../document/values/map_value.dart';
import '../../sledge_connection_id.dart';
import '../base_type.dart';

/// The Sledge type for Map from String to Uint8List.
/// Last One Wins strategy is applied for conflict resolution per key.
class BytelistMap implements BaseType {
  @override
  String toJson() => 'BytelistMap';

  @override
  Value newValue(ConnectionId connectionId) =>
      MapValue<String, Uint8List>();
}
