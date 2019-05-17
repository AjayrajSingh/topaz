// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('Save a document', () async {
    final pageId = SledgePageId('some page');
    final ledgerInstanceProvider = await newLedgerTestInstanceProvider();
    final activeSledge = await newSledgeForTesting(
        ledgerInstanceProvider: ledgerInstanceProvider, pageId: pageId);
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someInteger': Integer()
    };
    Schema schema = Schema(schemaDescription);
    DocumentId id = DocumentId(schema);

    // Store a document in Sledge.
    await activeSledge.runInTransaction(() async {
      final List<Document> documents =
          await activeSledge.getDocuments(Query(schema));
      assert(documents.isEmpty);
      assert(await activeSledge.documentExists(id) == false);

      Document doc = await activeSledge.getDocument(id);
      assert(doc['someInteger'].value == 0);

      doc['someInteger'].value = 42;
      assert(doc['someInteger'].value == 42);
    });

    // Verify that the document is present when reading using a separate
    // Sledge instance.
    final passiveSledge = await newSledgeForTesting(
        ledgerInstanceProvider: ledgerInstanceProvider, pageId: pageId);
    await passiveSledge.runInTransaction(() async {
      final List<Document> documents =
          await passiveSledge.getDocuments(Query(schema));
      assert(documents.isNotEmpty);
      assert(await passiveSledge.documentExists(id) == true);
      Document doc = await passiveSledge.getDocument(id);
      assert(doc['someInteger'].value == 42);
    });

    // Verify that the document is not present in a Sledge instance
    // created with a different page.
    final unrelatedPageId = SledgePageId('some other page');
    final unrelatedSledge = await newSledgeForTesting(
        ledgerInstanceProvider: ledgerInstanceProvider,
        pageId: unrelatedPageId);
    await unrelatedSledge.runInTransaction(() async {
      final List<Document> documents =
          await unrelatedSledge.getDocuments(Query(schema));
      assert(documents.isEmpty);
    });

    // Change a document in [activeSledge] and wait until [passiveSledge] gets
    // the updates.
    // This tests that Ledger changes are properly propagated by Sledge.
    await activeSledge.runInTransaction(() async {
      Document doc = await activeSledge.getDocument(id);
      doc['someInteger'].value = 43;
    });

    int someInteger;
    while (someInteger != 43) {
      await passiveSledge.runInTransaction(() async {
        Document doc = await Future(() => passiveSledge.getDocument(id));
        someInteger = doc['someInteger'].value;
      });
    }
  });
}
