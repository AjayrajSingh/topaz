// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../document/value.dart';
import '../document/values/converter.dart';
import '../document/values/last_one_wins_value.dart';
import '../document/values/pos_neg_counter_value.dart';
import '../schema/base_type.dart';
import '../schema/types/pos_neg_counter_type.dart';
import '../schema/types/trivial_types.dart';

/// Stores the value of a field in queries.
abstract class FieldValue implements Comparable<Value> {
  /// The hash of the field's value.
  Uint8List get hash;

  /// Returns whether this can be compared to [type].
  bool comparableTo(BaseType type);
}

/// Template to ease the implementation of FieldValue specializations.
abstract class _TemplatedFieldValue<T> implements FieldValue {
  final _converter = new Converter<T>();
  T _value;

  _TemplatedFieldValue(this._value);

  @override
  Uint8List get hash => _converter.serialize(_value);
}

/// Specialization of `FieldValue` for integers.
class IntFieldValue extends _TemplatedFieldValue<int> {
  /// Default constructor.
  IntFieldValue(int value) : super(value);

  @override
  bool comparableTo(BaseType type) {
    if (type is Integer || type is IntCounter) {
      return true;
    }
    return false;
  }

  @override
  int compareTo(Value documentValue) {
    if (documentValue is PosNegCounterValue<int>) {
      return _value.compareTo(documentValue.value);
    }
    if (documentValue is LastOneWinsValue<int>) {
      return _value.compareTo(documentValue.value);
    }
    throw new ArgumentError('`documentValue` is not comparable to a integer.');
  }
}
