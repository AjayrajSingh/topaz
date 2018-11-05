// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../document/values/converter.dart';

/// Stores in queries the value of a field.
abstract class FieldValue {
  /// The hash of the field's value.
  Uint8List get hash;
}

/// Template to ease the implementation of FieldValue specializations.
class _TemplatedFieldValue<T> implements FieldValue {
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
}
