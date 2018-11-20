// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import '../document/change.dart';
import '../document/document.dart';
import '../document/document_id.dart';
import '../document/values/key_value.dart';
import '../uint8list_ops.dart';
import 'kv_encoding.dart' as sledge_storage;

/// Returns the key prefix used to store [document] in Ledger.
Uint8List _documentStorageKeyPrefix(Document document) {
  final documentId = document.documentId;
  final prefix = concatUint8Lists(
      sledge_storage.prefixForType(sledge_storage.KeyValueType.document),
      documentId.prefix);
  assert(prefix.length ==
      sledge_storage.typePrefixLength + DocumentId.prefixLength);
  return prefix;
}

/// Stores [document] into [page].
List<Future<ledger.Status>> saveDocumentToPage(
    Document document, ledger.Page page) {
  final updateLedgerFutures = <Future<ledger.Status>>[];

  final Uint8List documentPrefix = _documentStorageKeyPrefix(document);
  final Change change = document.getChange();

  // Forward the "deletes".
  for (Uint8List deletedKey in change.deletedKeys) {
    final completer = new Completer<ledger.Status>();
    final Uint8List keyWithDocumentPrefix =
        concatUint8Lists(documentPrefix, deletedKey);
    page.delete(
      keyWithDocumentPrefix,
      completer.complete,
    );
    updateLedgerFutures.add(completer.future);
  }

  // Forward the "puts".
  for (KeyValue kv in change.changedEntries) {
    final completer = new Completer<ledger.Status>();

    final Uint8List keyWithDocumentPrefix =
        concatUint8Lists(documentPrefix, kv.key);
    page.put(
      keyWithDocumentPrefix,
      kv.value,
      completer.complete,
    );
    updateLedgerFutures.add(completer.future);
  }

  return updateLedgerFutures;
}
