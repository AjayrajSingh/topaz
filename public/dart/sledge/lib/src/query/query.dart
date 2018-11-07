// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import '../document/document.dart';
import '../schema/schema.dart';
import '../storage/kv_encoding.dart' as sledge_storage;
import '../uint8list_ops.dart' as utils;
import 'field_value.dart';

/// Represents a query for retrieving documents from Sledge.
/// TODO: Add support for inequality.
class Query {
  final Schema _schema;

  /// Stores the value each document's field needs to have in order to be
  /// returned by the query.
  SplayTreeMap<String, FieldValue> _equalities;

  /// Default constructor.
  /// `schema` describes the type of documents the query returns.
  /// `equalities` associates field names with their expected values.
  /// Throws an exception if `equalities` references a field not part of
  /// `schema`.
  Query(this._schema, {Map<String, FieldValue> equalities}) {
    // TODO: throw an exception if `equalities` references fields not part of
    // `schema`.
    equalities ??= <String, FieldValue>{};
    equalities.forEach((fieldPath, fieldValue) {
      final expectedType = schema.fieldAtPath(fieldPath);
      if (!fieldValue.comparableTo(expectedType)) {
        String runtimeType = expectedType.runtimeType.toString();
        throw new ArgumentError(
            'Field `$fieldPath` of type `$runtimeType` is not comparable with `$fieldValue`.');
      }
    });
    _equalities = new SplayTreeMap<String, FieldValue>.from(equalities);
  }

  /// The Schema of documents returned by this query.
  Schema get schema => _schema;

  /// Returns whether this query filters the Documents based on the content of
  /// their fields.
  bool filtersDocuments() {
    return _equalities.isNotEmpty;
  }

  /// The prefix of the key values encoding the index that helps compute the
  /// results of this query.
  /// Must only be called if `filtersDocuments()` returns true.
  Uint8List prefixInIndex() {
    assert(filtersDocuments());
    List<Uint8List> hashes = <Uint8List>[];
    _equalities.forEach((field, value) {
      hashes.add(value.hash);
    });

    Uint8List equalityHash = utils.hash(utils.concatListOfUint8Lists(hashes));

    // TODO: get the correct index hash.
    Uint8List indexHash = new Uint8List(20);

    Uint8List prefix = utils.concatListOfUint8Lists([
      sledge_storage.prefixForType(sledge_storage.KeyValueType.indexEntry),
      indexHash,
      equalityHash
    ]);

    return prefix;
  }

  /// Returns whether [doc] is matched by the query.
  /// Throws an error if [doc] is not of the same Schema the query was created
  /// with.
  bool documentMatchesQuery(Document doc) {
    if (doc.documentId.schema != _schema) {
      throw new ArgumentError(
          'The Document `doc` is of a incorrect Schema type.');
    }
    for (final fieldName in _equalities.keys) {
      if (!_equalities[fieldName].equalsTo(doc[fieldName])) {
        return false;
      }
    }
    return true;
  }
}
