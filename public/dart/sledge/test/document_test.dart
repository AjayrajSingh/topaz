// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Schema newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': Integer()
  };
  return Schema(schemaDescription);
}

void main() async {
  setupLogger();

  test('Verify that document can be created.', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    // ignore: unused_local_variable
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(id);
    });
  });

  test(
      'Verify that by same DocumentId we get the same document object.'
      '(different transactions)', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
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
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      final future1 = sledge.getDocument(id);
      final future2 = sledge.getDocument(id);
      doc1 = await future1;
      doc2 = await future2;
    });
    expect(doc1, equals(doc2));
  });

  test(
      'Verify that by different documentId we get different document objects.'
      '(different transactions)', () async {
    Schema schema = newSchema();
    final id1 = DocumentId(schema), id2 = DocumentId(schema);
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
    final id1 = DocumentId(schema), id2 = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc1, doc2;
    await sledge.runInTransaction(() async {
      doc1 = await sledge.getDocument(id1);
      doc2 = await sledge.getDocument(id2);
    });
    expect(doc1, isNot(equals(doc2)));
  });

  test(
      'Check that creating then rolling back a document does not prevent from'
      'creating it later', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    await sledge.runInTransaction(() async {
      await sledge.getDocument(id);
      sledge.abortAndRollback();
    });
    await sledge.runInTransaction(() async {
      bool exists = await sledge.documentExists(id);
      expect(exists, equals(false));
    });
    await sledge.runInTransaction(() async {
      await sledge.getDocument(id);
    });
    await sledge.runInTransaction(() async {
      bool exists = await sledge.documentExists(id);
      expect(exists, equals(true));
    });
  });

  test('Check that operations on non-existing documents throw exceptions',
      () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(id);
      sledge.abortAndRollback();
    });
    expect(() => doc['a'].value, throwsStateError);
    await sledge.runInTransaction(() async {
      expect(() => doc['a'].value, throwsStateError);
      expect(() => doc['a'].value = 2, throwsStateError);
      doc = await sledge.getDocument(id);
      expect(() => doc['a'].value, isNot(throwsStateError));
    });
  });
}
