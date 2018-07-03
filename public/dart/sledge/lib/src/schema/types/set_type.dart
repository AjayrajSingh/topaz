// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../document/base_value.dart';
import '../../document/values/set_value.dart';
import '../../sledge_connection_id.dart';
import '../base_type.dart';

/// The Sledge type for Set of [Uint8List].
/// Last One Wins strategy is applied for conflict resolution per entry.
class BytelistSet implements BaseType {
  static const _listEquality = const ListEquality<int>();

  @override
  String toJson() => 'BytelistSet';

  @override
  BaseValue newValue(ConnectionId connectionId) => new SetValue<Uint8List>(
      equals: _listEquality.equals, hashCode: _listEquality.hash);
}
