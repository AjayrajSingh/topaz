// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:sledge/src/query/field_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import 'helpers.dart';

Schema _newSchema1() {
  final schemaDescription = <String, BaseType>{'s1': LastOneWinsString()};
  return Schema(schemaDescription);
}

Schema _newSchema2() {
  final schemaDescription = <String, BaseType>{'s2': LastOneWinsString()};
  return Schema(schemaDescription);
}

Schema _newSchema3() {
  final schemaDescription = <String, BaseType>{
    'i1': Integer(),
    'i2': Integer(),
    's3': LastOneWinsString(),
  };
  return Schema(schemaDescription);
}

void main() async {
  setupLogger();

  group('Queries with just a schema.', () {
    test('Verify that getDocuments returns an empty list', () async {
      Schema schema = _newSchema1();
      Sledge sledge = newSledgeForTesting();
      await sledge.runInTransaction(() async {
        final query = Query(schema);
        final docs = await sledge.getDocuments(query);
        expect(docs.length, equals(0));
      });
    });

    test('Verify that getDocuments returns multiple documents', () async {
      Schema schema1 = _newSchema1();
      Schema schema2 = _newSchema2();
      Sledge sledge = newSledgeForTesting();

      Document docA;
      Document docB;
      // Save 3 documents in Sledge, two of which are instances of schema1.
      await sledge.runInTransaction(() async {
        docA = await sledge.getDocument(DocumentId(schema1));
        docA['s1'].value = 'foo';
        docB = await sledge.getDocument(DocumentId(schema1));
        docB['s1'].value = 'bar';
        final otherDoc = await sledge.getDocument(DocumentId(schema2));
        otherDoc['s2'].value = 'baz';

        // Verify that `getDocuments` does not return any documents.
        final docs = await sledge.getDocuments(Query(schema1));
        expect(docs.length, equals(0));
      });

      // Verify that `getDocuments` returns all instances of schema1.
      await sledge.runInTransaction(() async {
        final docs = await sledge.getDocuments(Query(schema1));
        expect(docs.length, equals(2));
        expect(docs, contains(docA));
        expect(docs, contains(docB));
      });
    });
  });

  group('Queries with equalities.', () {
    test('Verify that getDocuments returns an empty list', () async {
      Schema schema = _newSchema3();
      Sledge sledge = newSledgeForTesting();
      await sledge.runInTransaction(() async {
        final comparisons = <String, QueryFieldComparison>{
          'i1': QueryFieldComparison(
              NumFieldValue(42), ComparisonType.equal)
        };
        final query = Query(schema, comparisons: comparisons);
        final docs = await sledge.getDocuments(query);
        expect(docs.length, equals(0));
      });
    });

    test('Verify that getDocuments returns documents', () async {
      Schema schema = _newSchema3();
      Sledge sledge = newSledgeForTesting();
      // Create 5 documents.
      Document doc1;
      Document doc2;
      Document doc3;
      Document doc4;
      Document doc5;
      await sledge.runInTransaction(() async {
        doc1 = await sledge.getDocument(DocumentId(schema));
        doc1['i1'].value = 1;
        doc1['i2'].value = 10;
        doc2 = await sledge.getDocument(DocumentId(schema));
        doc2['i1'].value = 2;
        doc2['i2'].value = 20;
        doc3 = await sledge.getDocument(DocumentId(schema));
        doc3['i1'].value = 1;
        doc3['i2'].value = 30;
        doc4 = await sledge.getDocument(DocumentId(schema));
        doc4['i1'].value = 2;
        doc4['i2'].value = 30;
        doc5 = await sledge.getDocument(DocumentId(schema));
        doc5['i1'].value = 2;
        doc5['i2'].value = 20;
      });
      // Verify the resuts of queries with equalities.
      await sledge.runInTransaction(() async {
        {
          QueryBuilder qb = QueryBuilder(schema)..addEqual('i1', 1);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(2));
          expect(docs, containsAll([doc1, doc3]));
        }
        {
          QueryBuilder qb = QueryBuilder(schema)..addEqual('i2', 30);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(2));
          expect(docs, containsAll([doc3, doc4]));
        }
        {
          QueryBuilder qb = QueryBuilder(schema)
            ..addEqual('i1', 2)
            ..addEqual('i2', 30);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(1));
          expect(docs, containsAll([doc4]));
        }
      });
      // Verify the resuts of queries with inequalities.
      await sledge.runInTransaction(() async {
        final lessQb = QueryBuilder(schema)..addLess('i2', 20);
        final lessOrEqualQb = QueryBuilder(schema)
          ..addLessOrEqual('i2', 20);
        final greaterOrEqualQb = QueryBuilder(schema)
          ..addGreaterOrEqual('i2', 20);
        final greaterQb = QueryBuilder(schema)..addGreater('i2', 20);
        {
          final docs = await sledge.getDocuments(lessQb.build());
          expect(docs.length, equals(1));
          expect(docs, containsAll([doc1]));
        }
        {
          final docs = await sledge.getDocuments(lessOrEqualQb.build());
          expect(docs.length, equals(3));
          expect(docs, containsAll([doc1, doc2, doc5]));
        }
        {
          final docs = await sledge.getDocuments(greaterOrEqualQb.build());
          expect(docs.length, equals(4));
          expect(docs, containsAll([doc2, doc3, doc4, doc5]));
        }
        {
          final docs = await sledge.getDocuments(greaterQb.build());
          expect(docs.length, equals(2));
          expect(docs, containsAll([doc3, doc4]));
        }
      });
    });
  });
}
