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
  final schemaDescription = <String, BaseType>{'i1': new Integer()};
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
        expect(query.requiresIndex(), equals(false));
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
        final equalities = <String, FieldValue>{'i1': new IntFieldValue(42)};
        final query = new Query(schema, equalities: equalities);
        expect(query.requiresIndex(), equals(true));
        final docs = await sledge.getDocuments(query);
        expect(docs.length, equals(0));
      });
    });
  });
}
