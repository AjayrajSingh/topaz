// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../../document/base_value.dart';
import '../../document/values/ordered_list_value.dart';
import '../../sledge_connection_id.dart';
import '../base_type.dart';

/// The Sledge type for Ordered Set of [Uint8List].
class OrderedList implements BaseType {
  @override
  String toJson() => 'OrderedList';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new OrderedListValue<Uint8List>(connectionId.id);
}
