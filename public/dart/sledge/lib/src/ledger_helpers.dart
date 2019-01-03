// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl.dart';
import 'package:zircon/zircon.dart' show ZX, ReadResult;

import 'document/change.dart';
import 'document/values/key_value.dart';
import 'uint8list_ops.dart';

// ignore_for_file: one_member_abstracts
/// Factory that creates ledger proxies and bindings.
abstract class LedgerObjectsFactory {
  /// Returns a new PageSnapshotProxy.
  ledger.PageSnapshotProxy newPageSnapshotProxy();

  /// Returns a new PageWatcherBinding.
  ledger.PageWatcherBinding newPageWatcherBinding();
}

/// Real implementation of LedgerObjectsFactory.
class LedgerObjectsFactoryImpl implements LedgerObjectsFactory {
  @override
  ledger.PageSnapshotProxy newPageSnapshotProxy() =>
      new ledger.PageSnapshotProxy();

  @override
  ledger.PageWatcherBinding newPageWatcherBinding() =>
      new ledger.PageWatcherBinding();
}

/// Throws an exception containing [operation] if the status is not `ok`.
void checkStatus(ledger.Status status, String operation) {
  if (status != ledger.Status.ok) {
    throw new Exception('Ledger operation `$operation` failed.');
  }
}

/// Returns data stored in [buffer].
Uint8List readBuffer(Buffer buffer) {
  ReadResult readResult = buffer.vmo.read(buffer.size);
  if (readResult.status != ZX.OK) {
    throw new Exception('Unable to read from vmo `${readResult.status}`.');
  }
  if (readResult.bytes.lengthInBytes != buffer.size) {
    throw new Exception('Unexpected count of bytes read.');
  }
  return new Uint8List.view(readResult.bytes.buffer);
}

/// Helper method for the [getFullEntries] method.
Future<Null> _getFullEntriesRecursively(
  ledger.PageSnapshot snapshot,
  List<ledger.Entry> result,
  List<int> keyPrefix, {
  ledger.Token token,
}) async {
  Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
  List<ledger.Entry> entries;
  ledger.Token nextToken;

  snapshot.getEntries(keyPrefix ?? new Uint8List(0), token,
      (ledger.Status status, List<ledger.Entry> entriesResult,
          ledger.Token nextTokenResult) {
    entries = entriesResult;
    nextToken = nextTokenResult;
    statusCompleter.complete(status);
  });

  ledger.Status status = await statusCompleter.future;

  if (status != ledger.Status.ok && status != ledger.Status.partialResult) {
    throw new Exception(
        'PageSnapshot::GetEntries() returned an error status: $status');
  }

  result.addAll(entries.takeWhile((entry) => hasPrefix(entry.key, keyPrefix)));

  if (status == ledger.Status.partialResult &&
      hasPrefix(entries[entries.length - 1].key, keyPrefix)) {
    return _getFullEntriesRecursively(
      snapshot,
      result,
      keyPrefix,
      token: nextToken,
    );
  }
}

/// Gets the full list of [Entry] objects from a given [PageSnapshot].
///
/// This will continuously call the [PageSnapshot.getEntries] method in case the
/// returned status code is [Status.partialResult].
Future<List<ledger.Entry>> getFullEntries(
  ledger.PageSnapshot snapshot, {
  List<int> keyPrefix,
}) async {
  List<ledger.Entry> entries = <ledger.Entry>[];
  await _getFullEntriesRecursively(snapshot, entries, keyPrefix);
  return entries;
}

/// Returns all the KV pairs stored in [pageSnapshotProxy] whose key start
/// with [keyPrefix].
/// The KV are ordered by key in ascending order.
Future<List<KeyValue>> getEntriesFromSnapshotWithPrefix(
    ledger.PageSnapshotProxy pageSnapshotProxy, Uint8List keyPrefix) async {
  final keyValues = <KeyValue>[];
  List<ledger.Entry> entries =
      await getFullEntries(pageSnapshotProxy, keyPrefix: keyPrefix);
  for (final entry in entries) {
    Uint8List k = entry.key;
    Uint8List v = readBuffer(entry.value);
    keyValues.add(new KeyValue(k, v));
  }
  return keyValues;
}

/// Returns Change with the same content as a pageChange.
Change getChangeFromPageChange(ledger.PageChange pageChange) {
  return new Change(
      pageChange.changedEntries
          .map((ledger.Entry entry) =>
              new KeyValue(entry.key, readBuffer(entry.value)))
          .toList(),
      pageChange.deletedKeys);
}

/// Returns from [mergeResultProvider] the list of KV conflicts.
/// TODO: Change the API so that it returns chunks.
Future<List<ledger.DiffEntry>> getConflictingDiff(
    ledger.MergeResultProvider mergeResultProvider) async {
  // TODO: implement.
  final diff = <ledger.DiffEntry>[];
  return diff;
}
