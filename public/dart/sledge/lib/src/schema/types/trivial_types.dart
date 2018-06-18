// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../../document/base_value.dart';
import '../../document/values/last_one_wins_value.dart';
import '../../sledge_connection_id.dart';
import '../base_type.dart';

/// The Sledge type to store booleans.
class Boolean implements BaseType {
  @override
  String toJson() => 'Boolean';

  @override
  BaseValue newValue(ConnectionId connectionId) => new LastOneWinsValue<bool>();
}

/// The Sledge type to store integers.
class Integer implements BaseType {
  @override
  String toJson() => 'Integer';

  @override
  BaseValue newValue(ConnectionId connectionId) => new LastOneWinsValue<int>();
}

/// The Sledge type to store doubles.
class Double implements BaseType {
  @override
  String toJson() => 'Double';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new LastOneWinsValue<double>();
}

/// The Sledge type to store strings with LWW merging strategy.
class LastOneWinsString implements BaseType {
  @override
  String toJson() => 'LastOneWinsString';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new LastOneWinsValue<String>();
}

/// The Sledge type to store byte data with LWW merging strategy.
class LastOneWinsUint8List implements BaseType {
  @override
  String toJson() => 'LastOneWinsUint8List';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new LastOneWinsValue<Uint8List>();
}
