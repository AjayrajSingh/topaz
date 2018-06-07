// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl.dart';

import 'document/document.dart';
import 'document/document_id.dart';
import 'sledge_page_id.dart';

/// The interface to the Sledge library.
class Sledge {
  final ComponentContextProxy _componentContextProxy =
      new ComponentContextProxy();
  final ledger.LedgerProxy _ledgerProxy = new ledger.LedgerProxy();
  final ledger.PageProxy _pageProxy = new ledger.PageProxy();

  // Contains the status of the initialization.
  // ignore: unused_field
  Future<bool> _initializationSucceeded;

  /// Default constructor.
  Sledge(final ModuleContext moduleContext, [SledgePageId pageId]) {
    pageId ??= new SledgePageId();

    moduleContext.getComponentContext(_componentContextProxy.ctrl.request());
    _componentContextProxy.getLedger(_ledgerProxy.ctrl.request(),
        (ledger.Status status) {
      if (status != ledger.Status.ok) {
        print('Sledge failed to connect to Ledger: $status');
      }
    });

    Completer<bool> initializationCompleter = new Completer<bool>();

    _ledgerProxy.ctrl.onConnectionError = () {
      initializationCompleter.complete(false);
    };

    _ledgerProxy.getPage(pageId.id, _pageProxy.ctrl.request(),
        (ledger.Status status) {
      if (status != ledger.Status.ok) {
        print('Sledge failed to GetPage: $status');
        initializationCompleter.complete(false);
      } else {
        initializationCompleter.complete(true);
      }
    });

    _initializationSucceeded = initializationCompleter.future;
  }

  /// Convenience constructor for tests.
  Sledge.testing();

  /// Closes connection to ledger.
  void close() {
    _pageProxy.ctrl.close();
    _ledgerProxy.ctrl.close();
    _componentContextProxy.ctrl.close();
  }

  /// Returns a new document that can be stored in Sledge.
  dynamic newDocument(DocumentId documentId) {
    return new Document(this, documentId);
  }
}
