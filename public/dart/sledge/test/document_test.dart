// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Schema newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': new Integer(),
    'b': new Integer()
  };
  return new Schema(schemaDescription);
}

void main() {
  test('Verify that document can be created.', () async {
    Schema schema = newSchema();
    final id = new DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc;
    sledge.runInTransaction(() async {
      doc = await sledge.getDocument(id);
    });
  });

  test(
      'Verify that by same DocumentId we get the same document object.'
      '(different transactions)', () async {
    Schema schema = newSchema();
    final id = new DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      doc1 = await sledge.getDocument(id);
    });
    await sledge.runInTransaction(() async {
      doc2 = await sledge.getDocument(id);
    });
    expect(doc1, equals(doc2));
  });

  test(
      'Verify that by same documentId we get the same document object.'
      '(same transaction)', () async {
    Schema schema = newSchema();
    final id = new DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      doc1 = await sledge.getDocument(id);
      doc2 = await sledge.getDocument(id);
    });
    expect(doc1, equals(doc2));
  });

  test(
      'Verify that by different documentId we get different document objects.'
      '(different transactions)', () async {
    Schema schema = newSchema();
    final id1 = new DocumentId(schema), id2 = new DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      doc1 = await sledge.getDocument(id1);
    });
    await sledge.runInTransaction(() async {
      doc2 = await sledge.getDocument(id2);
    });
    expect(doc1, isNot(equals(doc2)));
  });

  test(
      'Verify that by different documentId we get different document objects.'
      '(same transaction)', () async {
    Schema schema = newSchema();
    final id1 = new DocumentId(schema), id2 = new DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      doc1 = await sledge.getDocument(id1);
      doc2 = await sledge.getDocument(id2);
    });
    expect(doc1, isNot(equals(doc2)));
  });
}
