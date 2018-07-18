// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:sledge/sledge.dart';

/// Handles the lifecycle of the Test module.
class TestModel {
  void _runSledgeTest(final ModuleContext moduleContext) async {
    Sledge sledge =
        new Sledge.fromModule(moduleContext, new SledgePageId('my page'));

    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    DocumentId id = new DocumentId(schema);

    await sledge.runInTransaction(() async {
      dynamic doc = await sledge.getDocument(id);
      assert(doc.someBool.value == false);
      assert(doc.someInteger.value == 0);
      doc.someBool.value = true;
      doc.someInteger.value = 42;
      assert(doc.someBool.value == true);
      assert(doc.someInteger.value == 42);
    });
    await sledge.runInTransaction(() async {
      dynamic doc = await sledge.getDocument(id);
      assert(doc.someBool.value == true);
      assert(doc.someInteger.value == 42);
      print('it works!');
    });
  }

  void onReady(final ModuleContext moduleContext) =>
      _runSledgeTest(moduleContext);
}
