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
import 'types/map_type.dart';
import 'types/pos_neg_counter_type.dart';
import 'types/set_type.dart';
import 'types/trivial_types.dart';

export 'types/map_type.dart';
export 'types/pos_neg_counter_type.dart';
export 'types/set_type.dart';
export 'types/trivial_types.dart';

Map<String, BaseType> _buildJsonToTypeMap(List<BaseType> types) {
  final map = <String, BaseType>{};
  for (final type in types) {
    assert(type.toJson() is String);
    map[type.toJson()] = type;
  }
  return map;
}

/// Stores the schema of Sledge documents.
class Schema implements BaseType {
  // Needs to be an ordered map in order to iterate on the fields in a
  // consistent order, regardless of the order they were passed to the
  // constructor.
  final SplayTreeMap<String, BaseType> _schemaDescription;
  static final Map<String, BaseType> _jsonToType =
      _buildJsonToTypeMap(<BaseType>[
    new Boolean(),
    new Integer(),
    new Double(),
    new LastOneWinsString(),
    new LastOneWinsUint8List(),
    new IntCounter(),
    new DoubleCounter(),
    new BytelistMap(),
    new BytelistSet(),
  ]);

  /// Default constructor. Note that the values of the map can be other
  /// schemas.
  Schema(Map<String, BaseType> schemaDescription)
      : _schemaDescription = new SplayTreeMap.from(schemaDescription);

  /// Builds a Schema from a JSON object.
  Schema.fromJson(Map<String, dynamic> map)
      : _schemaDescription = new SplayTreeMap<String, BaseType>() {
    map.forEach((String name, dynamic value) {
      BaseType type;
      if (value is Map) {
        type = new Schema.fromJson(value);
      } else if (value is String) {
        type = _baseTypeFromString(value);
      } else {
        throw new ArgumentError('Invalid JSON.');
      }
      _schemaDescription[name] = type;
    });
  }

  @override
  Map<String, dynamic> toJson() =>
      new SplayTreeMap<String, dynamic>.from(_schemaDescription);

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
    // TODO: Compute a hash not based on the JSON representation.
    String jsonString = json.encode(this);
    Uint8List bytes = utf8.encode(jsonString);
    Uint8List digest = sha1.convert(bytes).bytes;
    assert(digest.length == 20);
    return digest;
  }

  static BaseType _baseTypeFromString(String typeName) {
    if (!_jsonToType.containsKey(typeName)) {
      throw new ArgumentError('Unknown type.');
    }
    return _jsonToType[typeName];
  }
}
