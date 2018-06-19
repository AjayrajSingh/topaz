// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl.dart';

import 'document/document.dart';
import 'document/document_id.dart';
import 'document/uint8list_ops.dart';
import 'ledger_helpers.dart';
import 'sledge_page_id.dart';
import 'transaction.dart';

/// The interface to the Sledge library.
class Sledge {
  final ComponentContextProxy _componentContextProxy;
  final ledger.LedgerProxy _ledgerProxy = new ledger.LedgerProxy();
  final ledger.PageProxy _pageProxy;

  // Cache to get document by documentId.prefix.
  final Map<Uint8List, Document> _documentByPrefix = _mapFactory.newMap();
  static final _mapFactory = new Uint8ListMapFactory<Document>();

  // The factories used for fake object injection.
  final LedgerPageSnapshotFactory _pageSnapshotFactory;

  // Contains the status of the initialization.
  // ignore: unused_field
  Future<bool> _initializationSucceeded;

  Transaction _currentTransaction;

  /// Default constructor.
  Sledge(this._componentContextProxy, [SledgePageId pageId])
      : _pageProxy = new ledger.PageProxy(),
        _pageSnapshotFactory = new LedgerPageSnapshotFactoryImpl() {
    pageId ??= new SledgePageId();

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

  /// Convenience factory for modules.
  factory Sledge.fromModule(final ModuleContext moduleContext,
      [SledgePageId pageId]) {
    ComponentContextProxy componentContextProxy = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContextProxy.ctrl.request());
    return new Sledge(componentContextProxy, pageId);
  }

  /// Convenience constructor for tests.
  Sledge.testing(this._pageProxy, this._pageSnapshotFactory)
      : _componentContextProxy = null {
    _initializationSucceeded = new Future.value(true);
  }

  /// Closes connection to ledger.
  void close() {
    _pageProxy.ctrl.close();
    _ledgerProxy.ctrl.close();
    _componentContextProxy.ctrl.close();
  }

  /// Transactionally save modifications.
  /// Await the end of the method before calling |runInTransaction| again.
  /// Returns false if an error occured and the modifications couldn't be
  /// commited.
  /// Returns true otherwise.
  Future<bool> runInTransaction(void modifications()) async {
    if (_currentTransaction != null) {
      throw new StateError('Transaction already started.');
    }
    _currentTransaction =
        new Transaction(this, _pageSnapshotFactory.newInstance());

    bool initializationSucceeded = await _initializationSucceeded;
    if (!initializationSucceeded) {
      _currentTransaction = null;
      return false;
    }

    // Run the modification.
    bool savingModificationsWasSuccesfull =
        await _currentTransaction.saveModifications(modifications, _pageProxy);

    _currentTransaction = null;

    return new Future.value(savingModificationsWasSuccesfull);
  }

  /// Returns the document identified with |documentId|.
  /// If the document does not exist or an error occurs, an empty
  /// document is returned.
  Future<Document> getDocument(DocumentId documentId) async {
    if (_currentTransaction == null) {
      throw new StateError('No transaction started.');
    }

    if (!_documentByPrefix.containsKey(documentId.prefix)) {
      _documentByPrefix[documentId.prefix] =
          await _currentTransaction.getDocument(documentId);
    }

    return _documentByPrefix[documentId.prefix];
  }

  /// Returns the current transaction.
  Transaction get transaction {
    if (_currentTransaction == null) {
      throw new StateError('No transaction started.');
    }
    return _currentTransaction;
  }
}
