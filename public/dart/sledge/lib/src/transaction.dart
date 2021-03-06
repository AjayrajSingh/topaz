// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

import 'document/change.dart';
import 'document/document.dart';
import 'document/document_id.dart';
import 'document/values/key_value.dart';
import 'ledger_helpers.dart';
import 'query/query.dart';
import 'sledge.dart';
import 'storage/document_storage.dart';
import 'storage/kv_encoding.dart' as sledge_storage;
import 'storage/schema_storage.dart';
import 'uint8list_ops.dart';

typedef Modification = Future Function();

/// A private exception used to abort and rollback transactions
class _RollbackException implements Exception {}

/// Runs a modification and tracks modified documents in order to write the
/// changes to Ledger.
class Transaction {
  // List of Documents modified during the transaction.
  final Set<Document> _documents = <Document>{};
  final Sledge _sledge;
  final ledger.PageProxy _pageProxy;
  final ledger.PageSnapshotProxy _pageSnapshotProxy;

  /// Default constructor.
  Transaction(
      this._sledge, this._pageProxy, LedgerObjectsFactory ledgerObjectsFactory)
      : _pageSnapshotProxy = ledgerObjectsFactory.newPageSnapshotProxy();

  /// Runs [modification].
  Future<bool> saveModification(Modification modification) async {
    // Start Ledger transaction.
    await _pageProxy.startTransaction();

    // Obtain the snapshot.
    // All the read operations in |modification| will read from that snapshot.
    await _pageProxy.getSnapshot(
      _pageSnapshotProxy.ctrl.request(),
      Uint8List(0),
      null,
    );

    try {
      // Execute the modifications.
      // The modifications may:
      // - obtain a handle to a document, which would trigger a call to |getDocument|.
      // - modify a document. This would result in |documentWasModified| being called.
      try {
        await modification();
      } on _RollbackException {
        _rollbackModification();
        return false;
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        _rollbackModification();
        rethrow;
      }

      // Iterate through all the documents modified by this transaction and
      // forward the updates (puts and deletes) to Ledger.
      for (final document in _documents) {
        if (document.state == DocumentState.available) {
          saveDocumentToPage(document, _pageProxy);
          await saveSchemaToPage(document.documentId.schema, _pageProxy);
        } else {
          await deleteDocumentFromPage(
              document, _pageProxy, _pageSnapshotProxy);
        }
      }

      // Finish the transaction by commiting.
      await _pageProxy.commit();

      // Notify the documents that the transaction has been completed.
      _documents
        ..forEach((Document document) => document.completeTransaction())
        ..clear();
      return true;
    } finally {
      _pageSnapshotProxy.ctrl.close();
    }
  }

  /// Abort and rollback the transaction
  void abortAndRollback() {
    throw _RollbackException();
  }

  /// Notification that [document] was modified.
  void documentWasModified(Document document) {
    _documents.add(document);
  }

  /// Returns the document identified with [documentId].
  /// If the document does not exist, a new document is returned.
  Future<Document> getDocument(DocumentId documentId) async {
    final document = Document(_sledge, documentId);
    Uint8List keyPrefix = concatUint8Lists(
        sledge_storage.prefixForType(sledge_storage.KeyValueType.document),
        documentId.prefix);
    List<KeyValue> kvs =
        await getEntriesFromSnapshotWithPrefix(_pageSnapshotProxy, keyPrefix);

    // Strip the document prefix from the KVs.
    for (int i = 0; i < kvs.length; i++) {
      kvs[i] = KeyValue(
          getSublistView(kvs[i].key,
              start: DocumentId.prefixLength + sledge_storage.typePrefixLength),
          kvs[i].value);
    }

    if (kvs.isNotEmpty) {
      final change = Change(kvs);
      document.applyChange(change);
    }

    return document;
  }

  /// Returns the list of the ids of all documents matching the given [query].
  /// The result will not contain any updates in progress in the current transaction.
  Future<List<DocumentId>> getDocumentIds(Query query) async {
    final documentIds = <DocumentId>[];

    if (query.filtersDocuments()) {
      // TODO: actually check if index is present.
      bool indexIsPresent = false;
      if (indexIsPresent) {
        Uint8List keyPrefix = query.prefixInIndex();
        List<KeyValue> keyValues = await getEntriesFromSnapshotWithPrefix(
            _pageSnapshotProxy, keyPrefix);
        for (KeyValue keyValue in keyValues) {
          documentIds.add(DocumentId(query.schema, keyValue.value));
        }
      } else {
        print('getDocumentIds called with missing index');
        List<DocumentId> documentIds =
            await getDocumentIds(Query(query.schema));
        final filteredDocumentIds = <DocumentId>[];
        for (final documentId in documentIds) {
          // TODO(LE-638): Avoid discarding the documents after reading them.
          final doc = await getDocument(documentId);
          if (query.documentMatchesQuery(doc)) {
            filteredDocumentIds.add(documentId);
          }
        }
        return filteredDocumentIds;
        // TODO: schedule a transaction that builds the index.
      }
    } else {
      Uint8List keyPrefix = concatUint8Lists(
          sledge_storage.prefixForType(sledge_storage.KeyValueType.document),
          query.schema.hash);

      // Get all entries that correspond to the given schema.
      List<KeyValue> keyValues =
          await getEntriesFromSnapshotWithPrefix(_pageSnapshotProxy, keyPrefix);
      // Entries are sorted by key, thus entries corresponding to the same
      // document will be in consecutive positions.
      Uint8List currentDocumentSubId;
      for (KeyValue keyValue in keyValues) {
        final newDocumentSubId =
            sledge_storage.documentSubIdFromKey(keyValue.key);
        if (!uint8ListsAreEqual(currentDocumentSubId, newDocumentSubId)) {
          documentIds.add(DocumentId(query.schema, newDocumentSubId));
          currentDocumentSubId = newDocumentSubId;
        }
      }
    }
    return documentIds;
  }

  /// Returns whether the document identified with [documentId] exists.
  Future<bool> documentExists(DocumentId documentId) async {
    Uint8List keyPrefix = concatUint8Lists(
        sledge_storage.prefixForType(sledge_storage.KeyValueType.document),
        documentId.prefix);
    List<KeyValue> kvs =
        await getEntriesFromSnapshotWithPrefix(_pageSnapshotProxy, keyPrefix);
    return kvs.isNotEmpty;
  }

  /// Rollback the documents that were modified during the transaction.
  void _rollbackModification() {
    _documents
      ..forEach((Document document) => document.rollbackChange())
      ..clear();
    _pageProxy.rollback();
  }
}
