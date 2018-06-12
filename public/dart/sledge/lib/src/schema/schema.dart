// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../document/base_value.dart';
import '../document/value_node.dart';
import 'base_type.dart';

export 'types/map_type.dart';
export 'types/pos_neg_counter_type.dart';
export 'types/set_type.dart';
export 'types/trivial_types.dart';

/// Stores the schema of Sledge documents.
class Schema implements BaseType {
  // Needs to be an ordered map in order to iterate on the fields in a
  // consistent order, regardless of the order they were passed to the
  // constructor.
  SplayTreeMap<String, BaseType> _schemaDescription;

  /// Default constructor. Note that the values of the map can be other
  /// schemas.
  Schema(Map<String, BaseType> schemaDescription) {
    _schemaDescription = new SplayTreeMap.from(schemaDescription);
  }

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
  Map<String, BaseType> get schemaDescription {
    return _schemaDescription;
  }

  /// Returns a 20 byte hash of the schema.
  Uint8List get hash {
    String json = jsonValue();
    Uint8List bytes = utf8.encode(json);
    Uint8List digest = sha1.convert(bytes).bytes;
    assert(digest.length == 20);
    return digest;
  }
}
