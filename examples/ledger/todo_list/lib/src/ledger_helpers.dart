// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:fidl_ledger/fidl.dart' as ledger;

/// Callback type that takes a status of a completed Ledger operation.
typedef bool OnLedgerResponse(ledger.Status status);

/// Creates a callback that takes a Ledger status and logs an error if the
/// status is not OK.
OnLedgerResponse handleLedgerResponse(String description) {
  return (ledger.Status status) {
    if (status != ledger.Status.ok) {
      print('[Todo List] Ledger error in $description: $status');
      return true;
    }
    return false;
  };
}

/// Retrieves all entries from a snapshot.
///
/// If the response is paginated, this method transparently makes multiple
/// Ledger calls, assemble the complete response and call [callback] exactly
/// once.
void getEntriesFromSnapshot(ledger.PageSnapshotProxy snapshot,
    void callback(ledger.Status status, Map<List<int>, String> items)) {
  _getEntriesRecursive(snapshot, <List<int>, String>{}, null, callback);
}

void _getEntriesRecursive(
    ledger.PageSnapshotProxy snapshot,
    Map<List<int>, String> items,
    List<int> token,
    void callback(ledger.Status status, Map<List<int>, String> items)) {
  snapshot.getEntriesInline(null, token, (ledger.Status status,
      List<ledger.InlinedEntry> entries, List<int> nextToken) {
    if (status != ledger.Status.ok && status != ledger.Status.partialResult) {
      callback(status, <List<int>, String>{});
      return;
    }
    if (entries != null) {
      for (final ledger.InlinedEntry entry in entries) {
        items[entry.key] = utf8.decode(entry.value);
      }
    }
    if (status == ledger.Status.ok) {
      callback(ledger.Status.ok, items);
      return;
    }
    _getEntriesRecursive(snapshot, items, nextToken, callback);
  });
}
