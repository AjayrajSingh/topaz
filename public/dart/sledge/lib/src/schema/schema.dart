// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../document/node_value.dart';
import '../document/value.dart';
import '../sledge_connection_id.dart';
import '../uint8list_ops.dart' as utils;
import 'base_type.dart';
import 'types/map_type.dart';
import 'types/ordered_list_type.dart';
import 'types/pos_neg_counter_type.dart';
import 'types/set_type.dart';
import 'types/trivial_types.dart';

export 'types/map_type.dart';
export 'types/ordered_list_type.dart';
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
    new OrderedList()
  ]);
  static const _listEquality = const ListEquality();

  /// The length of the hash of Schema, as returned by the hash getter.
  static const int hashLength = 20;

  /// Default constructor. Note that the values of the map can be other
  /// schemas.
  /// Throws an error if a field's name contains the '.' character.
  Schema(Map<String, BaseType> schemaDescription)
      : _schemaDescription = new SplayTreeMap.from(schemaDescription) {
    _schemaDescription.forEach((String name, dynamic value) {
      if (name.contains('.')) {
        throw new ArgumentError(
            'The field `$name` must not contain the `.` character.');
      }
    });
  }

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
  Value newValue(ConnectionId id) {
    return new NodeValue(_schemaDescription, id);
  }

  /// Returns a description of the schema.
  Map<String, BaseType> get schemaDescription {
    return _schemaDescription;
  }

  /// Returns the type of the field stored at the given field path.
  /// Returns null if the field path does not match any field.
  /// A field path is a concatenation of field names that fully identify
  /// a field.
  /// # Example:
  ///  Given the schema X, and the schema Y that embeds X:
  ///     X : { 'a' : String }
  ///     Y : { 'b' : X , 'c' : String}
  ///  The valid field paths of Y are:
  ///     'b.a', 'c'
  BaseType fieldAtPath(String fieldPath) {
    if (fieldPath == null) {
      return null;
    }
    final indexOfFirstPeriod = fieldPath.indexOf('.');
    if (indexOfFirstPeriod == -1) {
      // The path contains a single field name.
      return _schemaDescription[fieldPath];
    } else {
      // The path contains multiple field names.
      // The code extracts the top most field name, verifies that it points
      // to an other Schema, and calls `fieldAtPath` again on the new Schema.
      final topLevelFieldName = fieldPath.substring(0, indexOfFirstPeriod);
      final fieldType = _schemaDescription[topLevelFieldName];
      if (fieldType is Schema) {
        Schema subSchema = fieldType;
        final subPath = fieldPath.substring(indexOfFirstPeriod + 1);
        return subSchema.fieldAtPath(subPath);
      } else {
        return null;
      }
    }
  }

  /// Returns a 20 byte hash of the schema.
  Uint8List get hash {
    // TODO: Compute a hash not based on the JSON representation.
    String jsonString = json.encode(this);
    Uint8List bytes = utf8.encode(jsonString);
    Uint8List digest = utils.hash(bytes);
    assert(digest.length == hashLength);
    return digest;
  }

  static BaseType _baseTypeFromString(String typeName) {
    if (!_jsonToType.containsKey(typeName)) {
      throw new ArgumentError('Unknown type.');
    }
    return _jsonToType[typeName];
  }

  @override
  bool operator ==(dynamic other) {
    return other is Schema && _listEquality.equals(other.hash, hash);
  }

  @override
  int get hashCode => hash.hashCode;
}
