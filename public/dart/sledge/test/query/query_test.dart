// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:sledge/src/query/field_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import '../helpers.dart';

Schema _newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': LastOneWinsString(),
    'c': Integer(),
  };
  return Schema(schemaDescription);
}

Schema _newSchema2() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
  };
  return Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('Verify that creating invalid queries throws an error', () async {
    Schema schema = _newSchema();

    // Test invalid comparisons
    final comparisonWithNonExistantField = <String, QueryFieldComparison>{
      'foo':
          QueryFieldComparison(NumFieldValue(42), ComparisonType.equal)
    };
    expect(() => Query(schema, comparisons: comparisonWithNonExistantField),
        throwsArgumentError);
    final comparisonWithWrongType = <String, QueryFieldComparison>{
      'b': QueryFieldComparison(NumFieldValue(42), ComparisonType.equal)
    };
    expect(() => Query(schema, comparisons: comparisonWithWrongType),
        throwsArgumentError);

    // Test too many inequalities
    final comparisonWithMultipleInequalities = <String, QueryFieldComparison>{
      'a': QueryFieldComparison(
          NumFieldValue(42), ComparisonType.greater),
      'c': QueryFieldComparison(
          NumFieldValue(42), ComparisonType.greater)
    };
    expect(
        () =>
            Query(schema, comparisons: comparisonWithMultipleInequalities),
        throwsArgumentError);
  });

  test('Verify `filtersDocuments`', () async {
    Schema schema = _newSchema();

    final query1 = Query(schema);
    expect(query1.filtersDocuments(), equals(false));

    // Test with equalities
    final equality = <String, QueryFieldComparison>{
      'a': QueryFieldComparison(NumFieldValue(42), ComparisonType.equal)
    };
    final query2 = Query(schema, comparisons: equality);
    expect(query2.filtersDocuments(), equals(true));

    // Test with inequality
    final inequality = <String, QueryFieldComparison>{
      'a': QueryFieldComparison(
          NumFieldValue(42), ComparisonType.greater)
    };
    final query3 = Query(schema, comparisons: inequality);
    expect(query3.filtersDocuments(), equals(true));
  });

  test('Verify `documentMatchesQuery`', () async {
    Sledge sledge = newSledgeForTesting();
    Schema schema = _newSchema();
    final equality = <String, QueryFieldComparison>{
      'a': QueryFieldComparison(NumFieldValue(42), ComparisonType.equal)
    };
    final inequality = <String, QueryFieldComparison>{
      'a': QueryFieldComparison(
          NumFieldValue(42), ComparisonType.greater)
    };
    final queryWithoutFilter = Query(schema);
    final queryWithEqualities = Query(schema, comparisons: equality);
    final queryWithInequality = Query(schema, comparisons: inequality);
    await sledge.runInTransaction(() async {
      Document doc1 = await sledge.getDocument(DocumentId(schema));
      doc1['a'].value = 1;
      Document doc2 = await sledge.getDocument(DocumentId(schema));
      doc2['a'].value = 42;
      Document doc3 = await sledge.getDocument(DocumentId(schema));
      doc3['a'].value = 43;
      Document doc4 = await sledge.getDocument(DocumentId(_newSchema2()));
      doc4['a'].value = 42;
      expect(queryWithoutFilter.documentMatchesQuery(doc1), equals(true));
      expect(queryWithoutFilter.documentMatchesQuery(doc2), equals(true));
      expect(queryWithEqualities.documentMatchesQuery(doc1), equals(false));
      expect(queryWithEqualities.documentMatchesQuery(doc2), equals(true));
      expect(queryWithInequality.documentMatchesQuery(doc1), equals(false));
      expect(queryWithInequality.documentMatchesQuery(doc2), equals(false));
      expect(queryWithInequality.documentMatchesQuery(doc3), equals(true));
      expect(() => queryWithoutFilter.documentMatchesQuery(doc4),
          throwsArgumentError);
      expect(() => queryWithEqualities.documentMatchesQuery(doc4),
          throwsArgumentError);
      expect(() => queryWithInequality.documentMatchesQuery(doc4),
          throwsArgumentError);
    });
  });
}
