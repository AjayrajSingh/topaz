// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import 'document/change.dart';
import 'document/document.dart';
import 'document/values/key_value.dart';

/// Runs |modification| and tracks modified documents in order to write the
/// changes to Ledger.
class Transaction {
  // List of Documents modified during the transaction.
  final Set<Document> _documents = new Set<Document>();

  /// Runs |modifications| and saves the resulting changes to |_pageProxy|.
  Future<bool> saveModifications(
      void modifications(), ledger.PageProxy pageProxy) async {
    // Start Ledger transaction.
    Completer<ledger.Status> completer = new Completer<ledger.Status>();
    pageProxy.startTransaction(completer.complete);
    bool startTransactionOk = (await completer.future) == ledger.Status.ok;
    if (!startTransactionOk) {
      return false;
    }

    // Execute the modifications.
    modifications();

    // Iterate through all the documents modified by this transaction and
    // forward the changes to Ledger.
    // TODO: Don't await individual ledger operations, await the aggregation
    // of all the ledger operations.
    for (final document in _documents) {
      final Change change = Document.put(document);
      // Foward the "deletes".
      for (Uint8List deletedKey in change.deletedKeys) {
        completer = new Completer<ledger.Status>();
        pageProxy.delete(
          deletedKey,
          (ledger.Status status) => completer.complete(status),
        );
        bool deleteOk = (await completer.future) == ledger.Status.ok;
        if (!deleteOk) {
          rollbackModifications(pageProxy);
          return false;
        }
      }
      // Forward the "puts".
      for (KeyValue kv in change.changedEntries) {
        completer = new Completer<ledger.Status>();
        pageProxy.put(
          kv.key,
          kv.value,
          (ledger.Status status) => completer.complete(status),
        );
        bool putOk = (await completer.future) == ledger.Status.ok;
        if (!putOk) {
          rollbackModifications(pageProxy);
          return false;
        }
      }
    }

    completer = new Completer<ledger.Status>();
    pageProxy.commit(completer.complete);
    bool commitOk = (await completer.future) == ledger.Status.ok;
    if (!commitOk) {
      rollbackModifications(pageProxy);
      return false;
    }
    return true;
  }

  /// Notification that |document| was modified.
  void documentWasModified(Document document) {
    _documents.add(document);
  }

  /// Rollback the documents that were modified during the transaction.
  void rollbackModifications(ledger.PageProxy pageProxy) {
    // TODO: implement.
  }
}
