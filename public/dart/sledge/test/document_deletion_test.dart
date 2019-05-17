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
  };
  return Schema(schemaDescription);
}

void main() async {
  setupLogger();

  test('Test immediate deletions.', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(id);
      doc['a'].value = 32;
      doc.delete();
      expect(() => doc['a'].value, throwsStateError);
    });
    expect(() => doc['a'].value, throwsStateError);
  });

  test('Test deletions.', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();

    // Create document.
    await sledge.runInTransaction(() async {
      Document doc = await sledge.getDocument(id);
      doc['a'].value = 32;
    });
    // Verify that the document exists and delete it.
    await sledge.runInTransaction(() async {
      final query = Query(schema);
      final docs = await sledge.getDocuments(query);
      expect(docs.length, equals(1));
      docs[0].delete();
    });
    // Verify that document deos not exist anymore.
    await sledge.runInTransaction(() async {
      final query = Query(schema);
      final docs = await sledge.getDocuments(query);
      expect(docs.length, equals(0));
    });
  });

  test('Test rollbacked deletions.', () async {
    Schema schema = newSchema();
    final id = DocumentId(schema);
    Sledge sledge = newSledgeForTesting();
    Document doc;
    // Create document.
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(id);
      doc['a'].value = 42;
    });
    // Delete document and abort transaction.
    await sledge.runInTransaction(() async {
      doc.delete();
      sledge.abortAndRollback();
    });
    // Verify that the document still exists.
    expect(doc['a'].value, equals(42));
  });
}
