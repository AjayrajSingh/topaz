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
    Completer<ledger.Status> completer = new Completer<ledger.Status>();
    pageProxy.startTransaction(completer.complete);
    bool startTransactionOk = (await completer.future) == ledger.Status.ok;
    if (!startTransactionOk) {
      return false;
    }

    // Obtain the snapshot.
    completer = new Completer<ledger.Status>();
    pageProxy.getSnapshot(
      _pageSnapshotProxy.ctrl.request(),
      new Uint8List(0),
      null,
      completer.complete,
    );
    bool getSnapshotOk = (await completer.future) == ledger.Status.ok;
    if (!getSnapshotOk) {
      return false;
    }

    await modification();

    // Iterate through all the documents modified by this transaction and
    // forward the changes to Ledger.
    // TODO: Don't await individual ledger operations, await the aggregation
    // of all the ledger operations.
    for (final document in _documents) {
      final Change change = Document.getChange(document);

      final Uint8List documentPrefix = document.documentId.prefix;

      // Foward the "deletes".
      for (Uint8List deletedKey in change.deletedKeys) {
        completer = new Completer<ledger.Status>();
        final Uint8List keyWithDocumentPrefix =
            concatUint8Lists(documentPrefix, deletedKey);
        pageProxy.delete(
          keyWithDocumentPrefix,
          (ledger.Status status) => completer.complete(status),
        );
        bool deleteOk = (await completer.future) == ledger.Status.ok;
        if (!deleteOk) {
          rollbackModification(pageProxy);
          return false;
        }
      }
      // Forward the "puts".
      for (KeyValue kv in change.changedEntries) {
        completer = new Completer<ledger.Status>();

        final Uint8List keyWithDocumentPrefix =
            concatUint8Lists(documentPrefix, kv.key);
        pageProxy.put(
          keyWithDocumentPrefix,
          kv.value,
          (ledger.Status status) => completer.complete(status),
        );

        bool putOk = (await completer.future) == ledger.Status.ok;
        if (!putOk) {
          rollbackModification(pageProxy);
          return false;
        }
      }
    }

    completer = new Completer<ledger.Status>();
    pageProxy.commit(completer.complete);
    bool commitOk = (await completer.future) == ledger.Status.ok;
    if (!commitOk) {
      rollbackModification(pageProxy);
      return false;
    }
    _documents.clear();
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
  void rollbackModification(ledger.PageProxy pageProxy) {
    // TODO: implement.
  }
}
