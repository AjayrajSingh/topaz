// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../schema/base_type.dart';
import '../sledge_connection_id.dart';
import 'leaf_value.dart';
import 'value.dart';

/// Class that maps field names to values.
/// TODO: rename to NodeValue
class ValueNode implements Value {
  Map<Symbol, Value> _childValues;

  /// Default constructor. [schemaDescription] specifies the name and type of
  /// every field.
  ValueNode(
      Map<String, BaseType> schemaDescription, ConnectionId connectionId) {
    // Maps symbols to a value.
    _childValues = <Symbol, Value>{};

    schemaDescription.forEach((String name, BaseType type) {
      Value value = type.newValue(connectionId);
      assert(value != null);
      _childValues[new Symbol(name)] = value;
    });
  }

  /// Returns a Map from field name to value.
  Map<String, LeafValue> collectFields() {
    final fields = <String, LeafValue>{};
    _childValues.forEach((Symbol symbolName, Value value) {
      String name = symbolName.toString();
      if (value is ValueNode) {
        value
            .collectFields()
            .forEach((key, value) => fields['$name.$key'] = value);
      } else {
        assert(value is LeafValue);
        fields[name] = value;
      }
    });
    return fields;
  }

  /// Intercepts invocations to provide easy access to specific [_childValues].
  @override
  dynamic noSuchMethod(Invocation invocation) {
    Value value = _childValues[invocation.memberName];
    if (value == null) {
      super.noSuchMethod(invocation);
    }
    return value;
  }
}
