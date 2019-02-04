// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular_async;
import 'package:fidl/fidl.dart' as fidl;
import 'package:zircon/zircon.dart' show ChannelPair;

import 'document/change.dart';
import 'document/document.dart';
import 'document/document_id.dart';
import 'ledger_helpers.dart';
import 'modification_queue.dart';
import 'query/query.dart';
import 'sledge_connection_id.dart';
import 'sledge_page_id.dart';
import 'storage/kv_encoding.dart' as sledge_storage;
import 'subscription/subscription.dart';
import 'transaction.dart';
import 'uint8list_ops.dart';

// TODO: consider throwing exceptions when initialization or transaction fails.
// Instead of current approach to return false.

/// The interface to the Sledge library.
class Sledge {
  final ledger.LedgerProxy _ledgerProxy = new ledger.LedgerProxy();
  final ledger.PageProxy _pageProxy;
  final ConnectionId _connectionId = new ConnectionId.random();

  // Cache to get document by documentId.prefix.
  final Map<Uint8List, Future<Document>> _documentByPrefix =
      newUint8ListMap<Future<Document>>();

  // The factories used for fake object injection.
  final LedgerObjectsFactory _ledgerObjectsFactory;

  // Contains the status of the initialization.
  // ignore: unused_field
  Future<bool> _initializationSucceeded;

  ModificationQueue _modificationQueue;

  /// Default constructor.
  factory Sledge(ComponentContext componentContext, [SledgePageId pageId]) {
    fidl.InterfacePair<ledger.Ledger> ledgerPair = new fidl.InterfacePair();
    componentContext.getLedger(ledgerPair.passRequest());
    return new Sledge._(ledgerPair.passHandle(), pageId);
  }

  /// Internal constructor
  Sledge._(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      [SledgePageId pageId])
      : _pageProxy = new ledger.PageProxy(),
        _ledgerObjectsFactory = new LedgerObjectsFactoryImpl() {
    pageId ??= new SledgePageId();

    // The initialization sequence consists of:
    // 1/ Obtaining a LedgerProxy from the LedgerHandle.
    // 2/ Setting a conflict resolver on the LedgerProxy (not yet implemented).
    // 3/ Obtaining a LedgerPageProxy using the LedgerProxy.
    // 4/ Subscribing for change notifications on the LedgerPageProxy.
    // Any of these steps can fail.
    //
    // The following Completer is completed with `false` if an error occurs at
    // any step. It is completed with `true` if the 4th step finishes
    // succesfully.
    //
    // Operations that require the succesfull initialization of the Sledge
    // instance await the Future returned by this completer.
    Completer<bool> initializationCompleter = new Completer<bool>();

    _ledgerProxy.ctrl.onConnectionError = () {
      if (!initializationCompleter.isCompleted) {
        initializationCompleter.complete(false);
      }
    };

    _ledgerProxy.ctrl.bind(ledgerHandle);

    _ledgerProxy.getPage(pageId.id, _pageProxy.ctrl.request(),
        (ledger.Status status) {
      if (initializationCompleter.isCompleted) {
        return;
      }
      if (status != ledger.Status.ok) {
        initializationCompleter.complete(false);
        return;
      }
      _modificationQueue =
          new ModificationQueue(this, _ledgerObjectsFactory, _pageProxy);
      _subscribe(initializationCompleter);
    });

    _initializationSucceeded = initializationCompleter.future;
  }

  /// Constructor that takes a new-style binding of ComponentContext
  factory Sledge.forAsync(modular_async.ComponentContext componentContext,
      [SledgePageId pageId]) {
    final pair = new ChannelPair();
    componentContext.getLedger(new fidl.InterfaceRequest(pair.first));
    return new Sledge._(new fidl.InterfaceHandle(pair.second), pageId);
  }

  /// Convenience factory for modules.
  factory Sledge.fromModule(final ModuleContext moduleContext,
      [SledgePageId pageId]) {
    ComponentContextProxy componentContextProxy = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContextProxy.ctrl.request());
    return new Sledge(componentContextProxy, pageId);
  }

  /// Convenience constructor for tests.
  Sledge.testing(this._pageProxy, this._ledgerObjectsFactory) {
    Completer<bool> initializationCompleter = new Completer<bool>();
    _modificationQueue =
        new ModificationQueue(this, _ledgerObjectsFactory, _pageProxy);
    _subscribe(initializationCompleter);
    _initializationSucceeded = initializationCompleter.future;
  }

  /// Convenience constructor for integration tests.
  Sledge.fromLedgerHandle(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      [SledgePageId pageId])
      : this._(ledgerHandle, pageId);

  /// Closes connection to ledger.
  void close() {
    _pageProxy.ctrl.close();
    _ledgerProxy.ctrl.close();
  }

  /// Transactionally save modification.
  /// Returns false if an error occurred and the modification couldn't be
  /// committed.
  /// Returns true otherwise.
  Future<bool> runInTransaction(Modification modification) async {
    bool initializationSucceeded = await _initializationSucceeded;
    if (!initializationSucceeded) {
      return false;
    }
    return _modificationQueue.queueModification(modification);
  }

  /// Abort and rollback the current modification.
  /// Execution of the transaction does not continue past this point.
  void abortAndRollback() {
    if (currentTransaction == null) {
      throw new StateError('No transaction started.');
    }
    currentTransaction.abortAndRollback();
  }

  /// Returns the document identified with [documentId].
  /// If the document does not exist or an error occurs, an empty
  /// document is returned.
  Future<Document> getDocument(DocumentId documentId) {
    _verifyThatTransactionHasStarted();
    if (!_documentByPrefix.containsKey(documentId.prefix)) {
      _documentByPrefix[documentId.prefix] =
          currentTransaction.getDocument(documentId);
    }

    return _documentByPrefix[documentId.prefix].then((Document d) {
      return d..makeExist();
    });
  }

  /// Returns the list of all documents matching the given [query].
  Future<List<Document>> getDocuments(Query query) async {
    _verifyThatTransactionHasStarted();

    List<DocumentId> documentIds =
        await currentTransaction.getDocumentIds(query);
    List<Future<Document>> documents = <Future<Document>>[];
    for (final documentId in documentIds) {
      documents.add(getDocument(documentId));
    }
    return Future.wait(documents);
  }

  /// Returns whether the document identified with [documentId] exists.
  Future<bool> documentExists(DocumentId documentId) {
    _verifyThatTransactionHasStarted();
    return currentTransaction.documentExists(documentId);
  }

  /// Returns the current transaction.
  /// Returns null if no transaction is in progress.
  Transaction get currentTransaction {
    return _modificationQueue.currentTransaction;
  }

  /// Returns an ID, unique among active connections across devices.
  ConnectionId get connectionId => _connectionId;

  /// Calls applyChange for all registered documents.
  void _applyChange(Change change) {
    // Split the changes according to their type.
    final splittedChange =
        change.splitByPrefix(sledge_storage.typePrefixLength);
    // Select the changes that concern documents.
    final documentChange = splittedChange[sledge_storage
            .prefixForType(sledge_storage.KeyValueType.document)] ??
        new Change();
    // Split the changes according to the document they belong to.
    final splittedDocumentChange =
        documentChange.splitByPrefix(DocumentId.prefixLength);
    for (final documentChange in splittedDocumentChange.entries) {
      final prefix = documentChange.key;
      _documentByPrefix[prefix]?.then((document) {
        document.applyChange(documentChange.value);
      });
    }
  }

  /// Subscribes for page.onChange to perform applyChange.
  Subscription _subscribe(Completer<bool> subscriptionCompleter) {
    assert(_modificationQueue.currentTransaction == null,
        '`_subscribe` must be called before any transaction can start.');
    return new Subscription(
        _pageProxy, _ledgerObjectsFactory, _applyChange, subscriptionCompleter);
  }

  void _verifyThatTransactionHasStarted() {
    if (currentTransaction == null) {
      throw new StateError('No transaction started.');
    }
  }
}
