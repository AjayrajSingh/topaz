// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import '../document/document.dart';
import '../schema/schema.dart';
import '../storage/kv_encoding.dart' as sledge_storage;
import '../uint8list_ops.dart' as utils;
import 'query_field_comparison.dart';

/// Represents a query for retrieving documents from Sledge.
class Query {
  final Schema _schema;

  /// Stores a QueryFieldComparison each document's field needs respect in
  /// order to be returned by the query.
  SplayTreeMap<String, QueryFieldComparison> _comparisons;

  /// Default constructor.
  /// [schema] describes the type of documents the query returns.
  /// [comparisons] associates field names with constraints documents returned
  /// by the query respects.
  /// Throws an exception if [comparisons] references a field  not part of
  /// [schema], or if multiple inequalities are present.
  Query(this._schema, {Map<String, QueryFieldComparison> comparisons}) {
    comparisons ??= <String, QueryFieldComparison>{};
    final fieldsWithInequalities = <String>[];
    comparisons.forEach((fieldPath, comparison) {
      if (comparison.comparisonType != ComparisonType.equal) {
        fieldsWithInequalities.add(fieldPath);
      }
      _checkComparisonWithField(fieldPath, comparison);
    });
    if (fieldsWithInequalities.length > 1) {
      throw new ArgumentError(
          'Queries can have at most one inequality. Inequalities founds: $fieldsWithInequalities.');
    }
    _comparisons =
        new SplayTreeMap<String, QueryFieldComparison>.from(comparisons);
  }

  /// The Schema of documents returned by this query.
  Schema get schema => _schema;

  /// Returns whether this query filters the Documents based on the content of
  /// their fields.
  bool filtersDocuments() {
    return _comparisons.isNotEmpty;
  }

  /// The prefix of the key values encoding the index that helps compute the
  /// results of this query.
  /// Must only be called if `filtersDocuments()` returns true.
  Uint8List prefixInIndex() {
    assert(filtersDocuments());
    final equalityValueHashes = <Uint8List>[];
    _comparisons.forEach((field, comparison) {
      if (comparison.comparisonType == ComparisonType.equal) {
        equalityValueHashes.add(utils.getUint8ListFromString(field));
      }
    });

    Uint8List equalityHash =
        utils.hash(utils.concatListOfUint8Lists(equalityValueHashes));

    // TODO: get the correct index hash.
    Uint8List indexHash = new Uint8List(20);

    // TODO: take into account the inequality to compute the prefix.
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
    for (final fieldName in _comparisons.keys) {
      if (!_comparisons[fieldName].valueMatchesComparison(doc[fieldName])) {
        return false;
      }
    }
    return true;
  }

  void _checkComparisonWithField(
      String fieldPath, QueryFieldComparison comparison) {
    final expectedType = _schema.fieldAtPath(fieldPath);
    if (!comparison.comparisonValue.comparableTo(expectedType)) {
      String runtimeType = expectedType.runtimeType.toString();
      throw new ArgumentError(
          'Field `$fieldPath` of type `$runtimeType` is not comparable with `$comparison.comparisonValue`.');
    }
  }
}
