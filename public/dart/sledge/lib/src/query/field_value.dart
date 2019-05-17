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
abstract class _TemplatedFieldValue<T extends Comparable<T>>
    implements FieldValue {
  final _converter = Converter<T>();
  T _value;

  _TemplatedFieldValue(this._value);

  @override
  int compareTo(Value documentValue) {
    return _value.compareTo(_extractValue(documentValue));
  }

  T _extractValue(Value documentValue);

  @override
  Uint8List get hash => _converter.serialize(_value);
}

/// Specialization of `FieldValue` for numbers.
class NumFieldValue extends _TemplatedFieldValue<num> {
  /// Default constructor.
  NumFieldValue(num value) : super(value);

  @override
  bool comparableTo(BaseType type) {
    if (type is Integer ||
        type is IntCounter ||
        type is Double ||
        type is DoubleCounter) {
      return true;
    }
    return false;
  }

  @override
  num _extractValue(Value documentValue) {
    if (documentValue is PosNegCounterValue<int>) {
      return documentValue.value;
    }
    if (documentValue is LastOneWinsValue<int>) {
      return documentValue.value;
    }
    if (documentValue is PosNegCounterValue<double>) {
      return documentValue.value;
    }
    if (documentValue is LastOneWinsValue<double>) {
      return documentValue.value;
    }
    throw ArgumentError('`documentValue` does not store a num.');
  }
}
