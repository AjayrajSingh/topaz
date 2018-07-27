// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import 'document/change.dart';
import 'document/document.dart';
import 'document/document_id.dart';
import 'document/uint8list_ops.dart';
import 'document/values/key_value.dart';
import 'ledger_helpers.dart';
import 'sledge.dart';
import 'storage/document_storage.dart';

typedef Modification = Future Function();

/// Runs a modification and tracks modified documents in order to write the
/// changes to Ledger.
class Transaction {
  // List of Documents modified during the transaction.
  final Set<Document> _documents = new Set<Document>();
  final Sledge _sledge;

  final ledger.PageSnapshotProxy _pageSnapshotProxy;

  /// Default constructor.
  Transaction(this._sledge, this._pageSnapshotProxy);

  /// Runs [modification] and saves the resulting changes to [pageProxy].
  Future<bool> saveModification(
      Modification modification, ledger.PageProxy pageProxy) async {
    // Start Ledger transaction.
    final startTransactionCompleter = new Completer<ledger.Status>();
    pageProxy.startTransaction(startTransactionCompleter.complete);
    bool startTransactionOk =
        (await startTransactionCompleter.future) == ledger.Status.ok;
    if (!startTransactionOk) {
      return false;
    }

    // Obtain the snapshot.
    final snapshotCompleter = new Completer<ledger.Status>();
    pageProxy.getSnapshot(
      _pageSnapshotProxy.ctrl.request(),
      new Uint8List(0),
      null,
      snapshotCompleter.complete,
    );
    bool getSnapshotOk = (await snapshotCompleter.future) == ledger.Status.ok;
    if (!getSnapshotOk) {
      return false;
    }

    await modification();

    final updateLedgerFutures = <Future<ledger.Status>>[];
    // Iterate through all the documents modified by this transaction and
    // forward the changes to Ledger.
    for (final document in _documents) {
      updateLedgerFutures.addAll(saveDocumentToPage(document, pageProxy));
    }

    final List<ledger.Status> statuses = await Future.wait(updateLedgerFutures);
    for (final status in statuses) {
      if (status != ledger.Status.ok) {
        await rollbackModification(pageProxy);
        return false;
      }
    }

    final commitCompleter = new Completer<ledger.Status>();
    pageProxy.commit(commitCompleter.complete);
    bool commitOk = (await commitCompleter.future) == ledger.Status.ok;
    if (!commitOk) {
      await rollbackModification(pageProxy);
      return false;
    }

    _documents
      ..forEach(Document.completeTransaction)
      ..clear();
    return true;
  }

  /// Notification that [document] was modified.
  void documentWasModified(Document document) {
    _documents.add(document);
  }

  /// Returns the document identified with [documentId].
  /// If the document does not exist, a new document is returned.
  Future<Document> getDocument(DocumentId documentId) async {
    final document = new Document(_sledge, documentId);
    Uint8List keyPrefix = documentId.prefix;
    List<KeyValue> kvs =
        await getEntriesFromSnapshotWithPrefix(_pageSnapshotProxy, keyPrefix);

    // Strip the document prefix from the KVs.
    for (int i = 0; i < kvs.length; i++) {
      kvs[i] = new KeyValue(
          getUint8ListSuffix(kvs[i].key, DocumentId.prefixLength),
          kvs[i].value);
    }

    if (kvs.isNotEmpty) {
      final change = new Change(kvs);
      Document.applyChange(document, change);
    }

    return document;
  }

  /// Rollback the documents that were modified during the transaction.
  Future rollbackModification(ledger.PageProxy pageProxy) async {
    _documents
      ..forEach(Document.rollbackChange)
      ..clear();
    final completer = new Completer<ledger.Status>();
    pageProxy.rollback(completer.complete);
    bool commitOk = (await completer.future) == ledger.Status.ok;
    if (!commitOk) {
      throw new Exception('Transaction failed. Unable to rollback.');
    }
  }
}
