// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger_async;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular_async;
import 'package:fidl/fidl.dart' as fidl;
import 'package:zircon/zircon.dart' show ChannelPair;

import 'document/change.dart';
import 'document/document.dart';
import 'document/document_id.dart';
import 'document/uint8list_ops.dart';
import 'ledger_helpers.dart';
import 'modification_queue.dart';
import 'sledge_connection_id.dart';
import 'sledge_page_id.dart';
import 'subscription/subscription.dart';
import 'transaction.dart';

// TODO: consider throwing exceptions when inintialization or transaction fails.
// Insted of current approach to return false.

/// The interface to the Sledge library.
class Sledge {
  final ledger.LedgerProxy _ledgerProxy = new ledger.LedgerProxy();
  final ledger.PageProxy _pageProxy;
  final ConnectionId _connectionId = new ConnectionId.random();

  // Cache to get document by documentId.prefix.
  final Map<Uint8List, Future<Document>> _documentByPrefix =
      _mapFactory.newMap();
  static final _mapFactory = new Uint8ListMapFactory<Future<Document>>();

  // The factories used for fake object injection.
  final LedgerPageSnapshotFactory _pageSnapshotFactory;

  // Contains the status of the initialization.
  // ignore: unused_field
  Future<bool> _initializationSucceeded;

  ModificationQueue _modificationQueue;

  /// Default constructor.
  factory Sledge(ComponentContext componentContext, [SledgePageId pageId]) {
    fidl.InterfacePair<ledger.Ledger> ledgerPair = new fidl.InterfacePair();
    componentContext.getLedger(ledgerPair.passRequest(),
        (ledger.Status status) {
      if (status != ledger.Status.ok) {
        print('Sledge failed to connect to Ledger: $status');
      }
    });

    return new Sledge._(ledgerPair.passHandle(), pageId);
  }

  /// Internal contructor
  Sledge._(fidl.InterfaceHandle<ledger.Ledger> ledgerHandle,
      [SledgePageId pageId])
      : _pageProxy = new ledger.PageProxy(),
        _pageSnapshotFactory = new LedgerPageSnapshotFactoryImpl() {
    pageId ??= new SledgePageId();

    _ledgerProxy.ctrl.bind(ledgerHandle);

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
        _modificationQueue =
            new ModificationQueue(this, _pageSnapshotFactory, _pageProxy);
        _subscribe(initializationCompleter);
      }
    });

    _initializationSucceeded = initializationCompleter.future;
  }

  /// Contructor that takes a new-style binding of ComponentContext
  factory Sledge.forAsync(modular_async.ComponentContext componentContext,
      [SledgePageId pageId]) {
    final pair = new ChannelPair();
    componentContext
        .getLedger(new fidl.InterfaceRequest(pair.first))
        .then((status) async {
      if (status != ledger_async.Status.ok) {
        print('Sledge failed to connect to Ledger: $status');
      }
    });

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
  Sledge.testing(this._pageProxy, this._pageSnapshotFactory) {
    _modificationQueue =
        new ModificationQueue(this, _pageSnapshotFactory, _pageProxy);
    _initializationSucceeded = new Future.value(true);
  }

  /// Closes connection to ledger.
  void close() {
    _pageProxy.ctrl.close();
    _ledgerProxy.ctrl.close();
  }

  /// Transactionally save modification.
  /// Returns false if an error occured and the modification couldn't be
  /// commited.
  /// Returns true otherwise.
  Future<bool> runInTransaction(Modification modification) async {
    bool initializationSucceeded = await _initializationSucceeded;
    if (!initializationSucceeded) {
      return false;
    }
    return _modificationQueue.queueModification(modification);
  }

  /// Returns the document identified with [documentId].
  /// If the document does not exist or an error occurs, an empty
  /// document is returned.
  Future<Document> getDocument(DocumentId documentId) {
    // TODO: Throw an error only if the document has not been instantiated
    // before.
    if (currentTransaction == null) {
      throw new StateError('No transaction started.');
    }
    if (!_documentByPrefix.containsKey(documentId.prefix)) {
      _documentByPrefix[documentId.prefix] =
          currentTransaction.getDocument(documentId);
    }

    return _documentByPrefix[documentId.prefix];
  }

  /// Returns the current transaction.
  /// Returns null if no transaction is in progress.
  Transaction get currentTransaction {
    return _modificationQueue.currentTransaction;
  }

  /// Returns an ID, unique among active connections accross devices.
  ConnectionId get connectionId => _connectionId;

  /// Calls applyChange for all registered documents.
  void _applyChange(Change change) {
    final splittedChange = change.splitByPrefix(DocumentId.prefixLength);
    for (final prefix in splittedChange.keys) {
      assert(_documentByPrefix.containsKey(prefix));
      _documentByPrefix[prefix].then((document) {
        Document.applyChange(document, splittedChange[prefix]);
      });
    }
  }

  /// Subscribes for page.onChange to perform applyChange.
  Subscription _subscribe(Completer<bool> subscriptionCompleter) {
    if (_modificationQueue.currentTransaction != null) {
      throw new StateError('Must be called before any transaction can start.');
    }
    return new Subscription(
        _pageProxy, _pageSnapshotFactory, _applyChange, subscriptionCompleter);
  }
}
