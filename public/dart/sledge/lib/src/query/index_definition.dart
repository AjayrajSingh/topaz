// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../schema/schema.dart';
import '../uint8list_ops.dart' as utils;

enum _ComparisonType { equality, inequality }

/// Sledge can be queried to return documents matching certain criteria on certain fields.
/// This class stores the information needed to maintain indexes to respond efficiently to
/// the queries.
/// The indexes can handle equality over multiple fields, and inequality on a single field.
class IndexDefinition {
  final Schema _schema;

  /// Stores the name of the field concerned by the index, and what kind of comparison is
  /// done over the said field.
  final _filterMap = SplayTreeMap<String, _ComparisonType>();

  static const _jsonFieldsMapKey = 'fields';
  static const _jsonSchemaKey = 'schema';
  static const int _hashLength = 20;

  /// Default constructor.
  /// `schema` defines on which Schema this Index applies.
  /// `fieldsWithEquality` is the list of fields on which equality statements will be run.
  /// `fieldWithInequality` is the name of the field on which the inequality statement and/or sorting can run.
  IndexDefinition(this._schema,
      {List<String> fieldsWithEquality, String fieldWithInequality}) {
    fieldsWithEquality ??= <String>[];
    for (final fieldWithEquality in fieldsWithEquality) {
      _checkBelongsToSchema(fieldWithEquality);
      if (_filterMap.containsKey(fieldWithEquality)) {
        throw ArgumentError(
            'Field `$fieldWithEquality` must not appear multiple times in fieldsWithEquality.');
      }
      if (fieldWithInequality == fieldWithEquality) {
        throw ArgumentError(
            'Field `$fieldWithEquality` must not be part of both fieldsWithEquality and fieldWithInequality.');
      }
      _filterMap[fieldWithEquality] = _ComparisonType.equality;
    }
    if (fieldWithInequality != null) {
      _checkBelongsToSchema(fieldWithInequality);
      _filterMap[fieldWithInequality] = _ComparisonType.inequality;
    }
  }

  /// Factory that builds an IndexDefinition from a JSON object.
  factory IndexDefinition.fromJson(Map<String, dynamic> map) {
    List<String> fieldsWithEquality = <String>[];
    String fieldWithInequality;
    map[_jsonFieldsMapKey].forEach((key, value) {
      _ComparisonType comp = _ComparisonType.values[value];
      switch (comp) {
        case _ComparisonType.equality:
          fieldsWithEquality.add(key);
          break;
        case _ComparisonType.inequality:
          fieldWithInequality = key;
          break;
      }
    });
    Schema schema = Schema.fromJson(map[_jsonSchemaKey]);
    return IndexDefinition(schema,
        fieldsWithEquality: fieldsWithEquality,
        fieldWithInequality: fieldWithInequality);
  }

  /// Returns the object'S JSON representation of the IndexDefinition.
  /// Called by dart:convert's JsonCodec.
  dynamic toJson() {
    Map<String, int> jsonFieldMap = _filterMap
        .map((key, value) => MapEntry<String, int>(key, value.index));
    final jsonMap = <String, dynamic>{
      _jsonFieldsMapKey: jsonFieldMap,
      _jsonSchemaKey: _schema
    };
    return jsonMap;
  }

  void _checkBelongsToSchema(String field) {
    if (!_schema.schemaDescription.containsKey(field)) {
      throw ArgumentError('Field `$field` is not part of the schema.');
    }
  }

  /// Returns a 20 byte hash.
  Uint8List get hash {
    // TODO: Compute a hash not based on the JSON representation.
    String jsonString = json.encode(this);
    Uint8List bytes = utf8.encode(jsonString);
    Uint8List digest = utils.hash(bytes);
    assert(digest.length == _hashLength);
    return digest;
  }
}
