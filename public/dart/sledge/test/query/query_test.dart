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
    final equalitiesWithNonExistantField = <String, FieldValue>{
      'foo': new IntFieldValue(42)
    };
    expect(() => new Query(schema, equalities: equalitiesWithNonExistantField),
        throwsArgumentError);
    final equalitiesWithWrongType = <String, FieldValue>{
      'b': new IntFieldValue(42)
    };
    expect(() => new Query(schema, equalities: equalitiesWithWrongType),
        throwsArgumentError);
  });

  test('Verify `filtersDocuments`', () async {
    Schema schema = _newSchema();
    final equalities = <String, FieldValue>{'a': new IntFieldValue(42)};

    final query2 = new Query(schema);
    expect(query2.filtersDocuments(), equals(false));
    final query1 = new Query(schema, equalities: equalities);
    expect(query1.filtersDocuments(), equals(true));
  });

  test('Verify `documentMatchesQuery`', () async {
    Sledge sledge = newSledgeForTesting();
    Schema schema = _newSchema();
    final equalities = <String, FieldValue>{'a': new IntFieldValue(42)};
    final query1 = new Query(schema);
    final query2 = new Query(schema, equalities: equalities);
    await sledge.runInTransaction(() async {
      Document doc1 = await sledge.getDocument(new DocumentId(schema));
      doc1['a'].value = 1;
      Document doc2 = await sledge.getDocument(new DocumentId(schema));
      doc2['a'].value = 42;
      Document doc3 = await sledge.getDocument(new DocumentId(_newSchema2()));
      doc3['a'].value = 42;
      expect(query1.documentMatchesQuery(doc1), equals(true));
      expect(query1.documentMatchesQuery(doc2), equals(true));
      expect(query2.documentMatchesQuery(doc1), equals(false));
      expect(query2.documentMatchesQuery(doc2), equals(true));
      expect(() => query1.documentMatchesQuery(doc3), throwsArgumentError);
      expect(() => query2.documentMatchesQuery(doc3), throwsArgumentError);
    });
  });
}
