// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';

/// Handles the lifecycle of the Test module.
class TestModel {
  void _runSledgeTest(final ModuleContext moduleContext) async {
    // Create a Sledge instance using the page `my page`.
    final pageId = new SledgePageId('my page');
    Sledge sledge = new Sledge.fromModule(moduleContext, pageId);

    // Store a document in the Sledge instance.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    DocumentId id = new DocumentId(schema);

    final intsReceivedInStream = <int>[];

    await sledge.runInTransaction(() async {
      dynamic doc = await sledge.getDocument(id);
      assert(doc.someBool.value == false);
      assert(doc.someInteger.value == 0);
      doc.someInteger.onChange.listen(intsReceivedInStream.add);

      doc.someBool.value = true;
      doc.someInteger.value = 42;
      assert(doc.someBool.value == true);
      assert(doc.someInteger.value == 42);
    });

    // Verify that the document is still present in a separate
    // transaction.
    await sledge.runInTransaction(() async {
      dynamic doc = await sledge.getDocument(id);
      assert(doc.someBool.value == true);
      assert(doc.someInteger.value == 42);
      doc.someInteger.value++;
    });

    // Create a new Sledge instance using the same page as before.
    Sledge sledge2 = new Sledge.fromModule(moduleContext, pageId);
    // Verify that the document is initialized.
    await sledge2.runInTransaction(() async {
      dynamic doc = await sledge2.getDocument(id);
      assert(doc.someBool.value == true);
      assert(doc.someInteger.value == 43);
    });

    // Create a new Sledge instance using a different page.
    Sledge sledge3 =
        new Sledge.fromModule(moduleContext, new SledgePageId('my other page'));
    // Verify that the document is not initialized.
    await sledge3.runInTransaction(() async {
      dynamic doc = await sledge3.getDocument(id);
      assert(doc.someBool.value == false);
      assert(doc.someInteger.value == 0);
    });

    assert(intsReceivedInStream.length == 2);
    assert(intsReceivedInStream[0] == 42);
    assert(intsReceivedInStream[1] == 43);
    log.info('it works!');
  }

  void onReady(final ModuleContext moduleContext) =>
      _runSledgeTest(moduleContext);
}
