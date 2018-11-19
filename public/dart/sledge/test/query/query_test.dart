// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:sledge/src/query/field_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import '../helpers.dart';

Schema _newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': new Integer(),
    'b': new LastOneWinsString(),
    'c': new Integer(),
  };
  return new Schema(schemaDescription);
}

Schema _newSchema2() {
  final schemaDescription = <String, BaseType>{
    'a': new Integer(),
  };
  return new Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('Verify that creating invalid queries throws an error', () async {
    Schema schema = _newSchema();

    // Test invalid comparisons
    final comparisonWithNonExistantField = <String, QueryFieldComparison>{
      'foo':
          new QueryFieldComparison(new NumFieldValue(42), ComparisonType.equal)
    };
    expect(() => new Query(schema, comparisons: comparisonWithNonExistantField),
        throwsArgumentError);
    final comparisonWithWrongType = <String, QueryFieldComparison>{
      'b': new QueryFieldComparison(new NumFieldValue(42), ComparisonType.equal)
    };
    expect(() => new Query(schema, comparisons: comparisonWithWrongType),
        throwsArgumentError);

    // Test too many inequalities
    final comparisonWithMultipleInequalities = <String, QueryFieldComparison>{
      'a': new QueryFieldComparison(
          new NumFieldValue(42), ComparisonType.greater),
      'c': new QueryFieldComparison(
          new NumFieldValue(42), ComparisonType.greater)
    };
    expect(
        () =>
            new Query(schema, comparisons: comparisonWithMultipleInequalities),
        throwsArgumentError);
  });

  test('Verify `filtersDocuments`', () async {
    Schema schema = _newSchema();

    final query1 = new Query(schema);
    expect(query1.filtersDocuments(), equals(false));

    // Test with equalities
    final equality = <String, QueryFieldComparison>{
      'a': new QueryFieldComparison(new NumFieldValue(42), ComparisonType.equal)
    };
    final query2 = new Query(schema, comparisons: equality);
    expect(query2.filtersDocuments(), equals(true));

    // Test with inequality
    final inequality = <String, QueryFieldComparison>{
      'a': new QueryFieldComparison(
          new NumFieldValue(42), ComparisonType.greater)
    };
    final query3 = new Query(schema, comparisons: inequality);
    expect(query3.filtersDocuments(), equals(true));
  });

  test('Verify `documentMatchesQuery`', () async {
    Sledge sledge = newSledgeForTesting();
    Schema schema = _newSchema();
    final equality = <String, QueryFieldComparison>{
      'a': new QueryFieldComparison(new NumFieldValue(42), ComparisonType.equal)
    };
    final inequality = <String, QueryFieldComparison>{
      'a': new QueryFieldComparison(
          new NumFieldValue(42), ComparisonType.greater)
    };
    final queryWithoutFilter = new Query(schema);
    final queryWithEqualities = new Query(schema, comparisons: equality);
    final queryWithInequality = new Query(schema, comparisons: inequality);
    await sledge.runInTransaction(() async {
      Document doc1 = await sledge.getDocument(new DocumentId(schema));
      doc1['a'].value = 1;
      Document doc2 = await sledge.getDocument(new DocumentId(schema));
      doc2['a'].value = 42;
      Document doc3 = await sledge.getDocument(new DocumentId(schema));
      doc3['a'].value = 43;
      Document doc4 = await sledge.getDocument(new DocumentId(_newSchema2()));
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
