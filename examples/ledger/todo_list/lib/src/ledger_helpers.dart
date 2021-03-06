// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

/// Retrieves all entries from a snapshot.
///
/// If the response is paginated, this method transparently makes multiple
/// Ledger calls, assemble the complete response and call [callback] exactly
/// once.
void getEntriesFromSnapshot(ledger.PageSnapshotProxy snapshot,
    void callback(Map<List<int>, String> items)) {
  _getEntriesRecursive(snapshot, <List<int>, String>{}, null, callback);
}

Future<void> _getEntriesRecursive(
    ledger.PageSnapshotProxy snapshot,
    Map<List<int>, String> items,
    ledger.Token token,
    void callback(Map<List<int>, String> items)) async {
  final response = await snapshot.getEntriesInline(Uint8List(0), token);
  final entries = response.entries;
  final nextToken = response.nextToken;

  for (final ledger.InlinedEntry entry in entries) {
    items[entry.key] = utf8.decode(entry.inlinedValue.value);
  }
  if (nextToken == null) {
    callback(items);
    return;
  }
  await _getEntriesRecursive(snapshot, items, nextToken, callback);
}
