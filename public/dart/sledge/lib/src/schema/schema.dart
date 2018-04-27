// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../document/base_value.dart';
import '../document/value_node.dart';
import 'base_type.dart';

export 'types/trivial_types.dart';

/// Stores the schema of Sledge documents.
class Schema implements BaseType {
  Map<String, BaseType> _schemaDescription;

  /// Default constructor. Note that the values of the map can be other
  /// schemas.
  // TODO(jif): Have |_schemaDescription| be a deep copy.
  Schema(this._schemaDescription);

  @override
  String jsonValue() {
    StringBuffer buffer = new StringBuffer('{');
    _schemaDescription.forEach((String name, BaseType type) {
      String jsonValue = type.jsonValue();
      buffer.write('\"$name\":$jsonValue,');
    });
    buffer.write('}');
    return buffer.toString();
  }

  @override
  BaseValue newValue() {
    return new ValueNode(_schemaDescription);
  }

  /// Returns a description of the schema.
  Map<String, BaseType> getSchemaDescription() {
    return _schemaDescription;
  }
}
