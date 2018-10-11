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
  Map<String, Value> _childValues;
  // TODO: remove
  Map<Symbol, Value> _childValuesDeprecated;

  /// Default constructor. [schemaDescription] specifies the name and type of
  /// every field.
  ValueNode(
      Map<String, BaseType> schemaDescription, ConnectionId connectionId) {
    _childValuesDeprecated = <Symbol, Value>{};
    _childValues = <String, Value>{};

    schemaDescription.forEach((String name, BaseType type) {
      Value value = type.newValue(connectionId);
      assert(value != null);
      _childValues[name] = value;
      _childValuesDeprecated[new Symbol(name)] = value;
    });
  }

  /// Returns a Map from field name to value.
  Map<String, LeafValue> collectFields() {
    final fields = <String, LeafValue>{};
    _childValues.forEach((String name, Value value) {
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

  /// Returns the child Value associated with [fieldName].
  /// If [fieldName] does not have any associated Value, an ArgumentError
  /// exception is thrown.
  dynamic operator [](String fieldName) {
    Value value = _childValues[fieldName];
    if (value == null) {
      throw new ArgumentError('Field `$fieldName` does not exist.');
    }
    return value;
  }
}
