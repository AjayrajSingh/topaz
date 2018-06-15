// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../../document/base_value.dart';
import '../../document/values/last_one_wins_value.dart';
import '../base_type.dart';

/// The Sledge type to store booleans.
class Boolean implements BaseType {
  @override
  String jsonValue() => '"Boolean"';

  @override
  BaseValue newValue() => new LastOneWinsValue<bool>();
}

/// The Sledge type to store integers.
class Integer implements BaseType {
  @override
  String jsonValue() => '"Integer"';

  @override
  BaseValue newValue() => new LastOneWinsValue<int>();
}

/// The Sledge type to store doubles.
class Double implements BaseType {
  @override
  String jsonValue() => '"Double"';

  @override
  BaseValue newValue() => new LastOneWinsValue<double>();
}

/// The Sledge type to store strings with LWW merging strategy.
class LastOneWinsString implements BaseType {
  @override
  String jsonValue() => '"LastOneWinsString"';

  @override
  BaseValue newValue() => new LastOneWinsValue<String>();
}

/// The Sledge type to store byte data with LWW merging strategy.
class LastOneWinsUint8List implements BaseType {
  @override
  String jsonValue() => '"LastOntWinsUint8List"';

  @override
  BaseValue newValue() => new LastOneWinsValue<Uint8List>();
}
