// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_sys/fidl_async.dart' show LaunchInfo, ComponentControllerProxy;
import 'package:lib.app.dart/app_async.dart' show Services, StartupContext;
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

class _LedgerTestInstance {
  _LedgerTestInstance(this._componentControllerProxy);
  InterfaceHandle<ledger.Ledger> ledgerHandle;
  // ignore: unused_field
  ComponentControllerProxy _componentControllerProxy;
}

/// Returns a new in-memory Ledger handle.
Future<_LedgerTestInstance> getInMemoryLedgerTestInstance() async {
  String server =
      'fuchsia-pkg://fuchsia.com/ledger_test_instance_provider#meta/ledger_test_instance_provider.cmx';
  final Services services = new Services();
  final LaunchInfo launchInfo =
      new LaunchInfo(url: server, directoryRequest: services.request());
  final context = new StartupContext.fromStartupInfo();
  final ComponentControllerProxy controller = new ComponentControllerProxy();
  await context.launcher.createComponent(launchInfo, controller.ctrl.request());

  final ledgerTestInstance = new _LedgerTestInstance(controller)
  ..ledgerHandle = await services.connectToServiceByName<ledger.Ledger>(ledger.Ledger.$serviceName);
  return ledgerTestInstance;
}

Completer<_LedgerTestInstance> _ledgerTestInstance;

/// Creates a new test Sledge instance backed by an in-memory Ledger.
Future<Sledge> getTestSledge() async {
  if (_ledgerTestInstance == null) {
    // If the completer has never been created, create it and start the process
    // of obtaining a LedgerTestInstance.
    _ledgerTestInstance = new Completer();
    final futureLedgerTestInstance = getInMemoryLedgerTestInstance();
    _ledgerTestInstance.complete(await futureLedgerTestInstance);
  }
  final ledgerTestInstance = await _ledgerTestInstance.future;
  final sledge = new Sledge.fromLedgerHandle(ledgerTestInstance.ledgerHandle);
  return sledge;
}

void main() {
  test('Save a document', () async {
    final sledge = await getTestSledge();
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    DocumentId id = new DocumentId(schema);

    // Store a document in Sledge.
    await sledge.runInTransaction(() async {
      final List<Document> documents =
          await sledge.getDocuments(new Query(schema));
      assert(documents.isEmpty);
      assert(await sledge.documentExists(id) == false);

      Document doc = await sledge.getDocument(id);
      assert(doc['someInteger'].value == 0);
      doc['someInteger'].value = 42;
      assert(doc['someInteger'].value == 42);
    });
  });
}
