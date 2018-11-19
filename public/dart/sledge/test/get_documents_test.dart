// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:sledge/src/query/field_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import 'helpers.dart';

Schema _newSchema1() {
  final schemaDescription = <String, BaseType>{'s1': new LastOneWinsString()};
  return new Schema(schemaDescription);
}

Schema _newSchema2() {
  final schemaDescription = <String, BaseType>{'s2': new LastOneWinsString()};
  return new Schema(schemaDescription);
}

Schema _newSchema3() {
  final schemaDescription = <String, BaseType>{
    'i1': new Integer(),
    'i2': new Integer(),
    's3': new LastOneWinsString(),
  };
  return new Schema(schemaDescription);
}

void main() async {
  setupLogger();

  group('Queries with just a schema.', () {
    test('Verify that getDocuments returns an empty list', () async {
      Schema schema = _newSchema1();
      Sledge sledge = newSledgeForTesting();
      await sledge.runInTransaction(() async {
        final query = new Query(schema);
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
        docA = await sledge.getDocument(new DocumentId(schema1));
        docA['s1'].value = 'foo';
        docB = await sledge.getDocument(new DocumentId(schema1));
        docB['s1'].value = 'bar';
        final otherDoc = await sledge.getDocument(new DocumentId(schema2));
        otherDoc['s2'].value = 'baz';

        // Verify that `getDocuments` does not return any documents.
        final docs = await sledge.getDocuments(new Query(schema1));
        expect(docs.length, equals(0));
      });

      // Verify that `getDocuments` returns all instances of schema1.
      await sledge.runInTransaction(() async {
        final docs = await sledge.getDocuments(new Query(schema1));
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
          'i1': new QueryFieldComparison(
              new NumFieldValue(42), ComparisonType.equal)
        };
        final query = new Query(schema, comparisons: comparisons);
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
        doc1 = await sledge.getDocument(new DocumentId(schema));
        doc1['i1'].value = 1;
        doc1['i2'].value = 10;
        doc2 = await sledge.getDocument(new DocumentId(schema));
        doc2['i1'].value = 2;
        doc2['i2'].value = 20;
        doc3 = await sledge.getDocument(new DocumentId(schema));
        doc3['i1'].value = 1;
        doc3['i2'].value = 30;
        doc4 = await sledge.getDocument(new DocumentId(schema));
        doc4['i1'].value = 2;
        doc4['i2'].value = 30;
        doc5 = await sledge.getDocument(new DocumentId(schema));
        doc5['i1'].value = 2;
        doc5['i2'].value = 20;
      });
      // Verify the resuts of queries with equalities.
      await sledge.runInTransaction(() async {
        {
          QueryBuilder qb = new QueryBuilder(schema)..addEqual('i1', 1);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(2));
          expect(docs, containsAll([doc1, doc3]));
        }
        {
          QueryBuilder qb = new QueryBuilder(schema)..addEqual('i2', 30);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(2));
          expect(docs, containsAll([doc3, doc4]));
        }
        {
          QueryBuilder qb = new QueryBuilder(schema)
            ..addEqual('i1', 2)
            ..addEqual('i2', 30);
          final docs = await sledge.getDocuments(qb.build());
          expect(docs.length, equals(1));
          expect(docs, containsAll([doc4]));
        }
      });
      // Verify the resuts of queries with inequalities.
      await sledge.runInTransaction(() async {
        final lessQb = new QueryBuilder(schema)..addLess('i2', 20);
        final lessOrEqualQb = new QueryBuilder(schema)
          ..addLessOrEqual('i2', 20);
        final greaterOrEqualQb = new QueryBuilder(schema)
          ..addGreaterOrEqual('i2', 20);
        final greaterQb = new QueryBuilder(schema)..addGreater('i2', 20);
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
