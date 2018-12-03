// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';

/// Handles the lifecycle of the Test module.
class TestModel {
  void _runSledgeTest(final ModuleContext moduleContext) async {
    bool testCompleted = false;
    // Set time limit on test execution.
    new Future.delayed(new Duration(seconds: 10), () {
      assert(testCompleted);
    });

    // Create a Sledge instance using the page `my page`.
    final pageId = new SledgePageId('my page');
    Sledge sledge = new Sledge.fromModule(moduleContext, pageId);

    Sledge sledgePassive = new Sledge.fromModule(moduleContext, pageId);

    // Make sure [sledgePassive] has completed its initialization.
    await sledgePassive.runInTransaction(() async {});

    // Store a document in the Sledge instance.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    DocumentId id = new DocumentId(schema);

    final intsReceivedInStream = <int>[];

    await sledge.runInTransaction(() async {
      final List<Document> documents =
          await sledge.getDocuments(new Query(schema));
      assert(documents.isEmpty);
      assert(await sledge.documentExists(id) == false);

      Document doc = await sledge.getDocument(id);

      assert(doc['someBool'].value == false);
      assert(doc['someInteger'].value == 0);
      doc['someInteger'].onChange.listen(intsReceivedInStream.add);

      doc['someBool'].value = true;
      doc['someInteger'].value = 42;
      assert(doc['someBool'].value == true);
      assert(doc['someInteger'].value == 42);
    });

    // Verify that the document is still present in a separate
    // transaction.
    await sledge.runInTransaction(() async {
      final List<Document> documents =
          await sledge.getDocuments(new Query(schema));
      assert(documents.length == 1);
      assert(documents[0]['someBool'].value == true);
      assert(documents[0]['someInteger'].value == 42);
      assert(await sledge.documentExists(id) == true);
      Document doc = await sledge.getDocument(id);
      assert(doc['someBool'].value == true);
      assert(doc['someInteger'].value == 42);
      doc['someInteger'].value++;
    });

    // Create a new Sledge instance using the same page as before.
    Sledge sledge2 = new Sledge.fromModule(moduleContext, pageId);
    // Verify that the document is initialized.
    await sledge2.runInTransaction(() async {
      final List<Document> documents = await sledge2.getDocuments(new Query(schema));
      assert(documents.length == 1);

      Document doc = await sledge2.getDocument(id);
      assert(doc['someBool'].value == true);
      assert(doc['someInteger'].value == 43);
    });

    // Create a new Sledge instance using a different page.
    Sledge sledge3 =
        new Sledge.fromModule(moduleContext, new SledgePageId('my other page'));
    // Verify that the document is not initialized.
    await sledge3.runInTransaction(() async {
      assert(await sledge3.documentExists(id) == false);
      Document doc = await sledge3.getDocument(id);
      assert(doc['someBool'].value == false);
      assert(doc['someInteger'].value == 0);
    });

    assert(intsReceivedInStream.length == 2);
    assert(intsReceivedInStream[0] == 42);
    assert(intsReceivedInStream[1] == 43);

    // Wait until [sledgePassive] got the latest updates.
    int someInteger;
    while (someInteger != 43) {
      await new Future.delayed(new Duration(milliseconds: 10), () => true);
      await sledgePassive.runInTransaction(() async {
        Document doc = await sledgePassive.getDocument(id);
        someInteger = doc['someInteger'].value;
      });
    }

    testCompleted = true;
    log.info('it works!');
  }

  void onReady(final ModuleContext moduleContext) =>
      _runSledgeTest(moduleContext);
}
