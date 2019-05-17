// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
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
  final ledger.LedgerProxy _ledgerProxy = ledger.LedgerProxy();
  final ledger.PageProxy _pageProxy;
  final ConnectionId _connectionId = ConnectionId.random();

  // Cache to get document by documentId.prefix.
  final Map<Uint8List, Future<Document>> _documentByPrefix =
      newUint8ListMap<Future<Document>>();

  // The factories used for fake object injection.
  final LedgerObjectsFactory _ledgerObjectsFactory;

  ModificationQueue _modificationQueue;

  Subscription _subscribtion;

  /// Default constructor.
  factory Sledge(modular.ComponentContext componentContext,
      [SledgePageId pageId]) {
    final pair = ChannelPair();
    componentContext.getLedger(fidl.InterfaceRequest(pair.first));
    return Sledge._(fidl.InterfaceHandle(pair.second), pageId);
  }

  /// Internal constructor
  Sledge._(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      [SledgePageId pageId])
      : _pageProxy = ledger.PageProxy(),
        _ledgerObjectsFactory = LedgerObjectsFactoryImpl() {
    pageId ??= SledgePageId();

    // The initialization sequence consists of:
    // 1/ Obtaining a LedgerProxy from the LedgerHandle.
    // 2/ Setting a conflict resolver on the LedgerProxy (not yet implemented).
    // 3/ Obtaining a LedgerPageProxy using the LedgerProxy.
    // 4/ Subscribing for change notifications on the LedgerPageProxy.

    _ledgerProxy.ctrl.whenClosed.then((_) {
      // TODO(jif): Handle disconnection from the Ledger.
    });

    _ledgerProxy.ctrl.bind(ledgerHandle);

    _ledgerProxy.getPage(pageId.id, _pageProxy.ctrl.request());
    _modificationQueue =
        ModificationQueue(this, _ledgerObjectsFactory, _pageProxy);
    _subscribtion = _subscribe();
  }

  /// Convenience constructor for tests.
  Sledge.testing(this._pageProxy, this._ledgerObjectsFactory) {
    _modificationQueue =
        ModificationQueue(this, _ledgerObjectsFactory, _pageProxy);
    _subscribtion = _subscribe();
  }

  /// Convenience constructor for integration tests.
  Sledge.fromLedgerHandle(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      [SledgePageId pageId])
      : this._(ledgerHandle, pageId);

  /// Closes connection to ledger.
  void close() {
    _subscribtion.unsubscribe();
    _pageProxy.ctrl.close();
    _ledgerProxy.ctrl.close();
  }

  /// Transactionally save modification.
  /// Returns false if an error occurred and the modification couldn't be
  /// committed.
  /// Returns true otherwise.
  Future<bool> runInTransaction(Modification modification) {
    return _modificationQueue.queueModification(modification);
  }

  /// Abort and rollback the current modification.
  /// Execution of the transaction does not continue past this point.
  void abortAndRollback() {
    if (currentTransaction == null) {
      throw StateError('No transaction started.');
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
        Change();
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
  Subscription _subscribe() {
    assert(_modificationQueue.currentTransaction == null,
        '`_subscribe` must be called before any transaction can start.');
    return Subscription(_pageProxy, _ledgerObjectsFactory, _applyChange);
  }

  void _verifyThatTransactionHasStarted() {
    if (currentTransaction == null) {
      throw StateError('No transaction started.');
    }
  }
}
