// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../schema/base_type.dart';
import 'base_value.dart';

/// Class that maps field names to values.
class ValueNode implements BaseValue {
  Map<Symbol, dynamic> _childValues;

  /// Default constructor. |schemaDescription| specifies the name and type of
  /// every field.
  ValueNode(Map<String, BaseType> schemaDescription) {
    // Maps symbols to a value.
    _childValues = <Symbol, Object>{};

    schemaDescription.forEach((String name, BaseType type) {
      Object value = type.newValue();
      assert(value != null);
      _childValues[new Symbol(name)] = value;
    });
  }

  /// Intercepts invocations to provide easy access to specific _childValues.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    Object value = _childValues[invocation.memberName];
    if (value == null) {
      super.noSuchMethod(invocation);
    }
    return value;
  }
}
