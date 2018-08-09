// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

// ignore_for_file: implementation_imports, library_prefixes
import 'package:fidl/fidl.dart' as $fidl;
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl.dart' as lib$fuchsia_mem;
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/key_value.dart';

import '../crdt_test_framework/storage_state.dart';
import 'fake_vmo.dart';

List<ledger.Entry> convertToEntries(final List<KeyValue> changedEntries) {
  final List<ledger.Entry> convertedEntries = <ledger.Entry>[];
  for (final keyValue in changedEntries) {
    convertedEntries.add(new ledger.Entry(
        key: keyValue.key,
        value: new lib$fuchsia_mem.Buffer(
            vmo: new FakeVmo(keyValue.value), size: keyValue.value.length),
        priority: new ledger.Priority(0)));
  }
  return convertedEntries;
}

class FakeLedgerPage extends ledger.PageProxy {
  StorageState _storageState;
  final Change _modification = new Change();
  dynamic _watcher;

  FakeLedgerPage() {
    _storageState = new StorageState(onChange);
  }

  ledger.Status putStatus;
  ledger.Status deleteStatus;
  ledger.Status startTransactionStatus;
  ledger.Status commitStatus;
  ledger.Status rollbackStatus;
  ledger.Status getSnapshotStatus;

  void resetAllStatus() {
    putStatus = null;
    deleteStatus = null;
    startTransactionStatus = null;
    commitStatus = null;
    rollbackStatus = null;
    getSnapshotStatus = null;
  }

  StorageState get storageState => _storageState;

  @override
  void put(
      Uint8List key, Uint8List value, void callback(ledger.Status status)) {
    _modification.changedEntries.add(new KeyValue(key, value));
    callback(putStatus ?? ledger.Status.ok);
  }

  @override
  void delete(Uint8List key, void callback(ledger.Status status)) {
    _modification.deletedKeys.add(key);
    callback(deleteStatus ?? ledger.Status.ok);
  }

  @override
  void startTransaction(void callback(ledger.Status status)) {
    assert(_modification.changedEntries.isEmpty);
    assert(_modification.deletedKeys.isEmpty);
    callback(startTransactionStatus ?? ledger.Status.ok);
  }

  @override
  void commit(void callback(ledger.Status status)) {
    _storageState.applyChange(_modification);
    onChange(_modification);
    _modification.clear();
    callback(commitStatus ?? ledger.Status.ok);
  }

  @override
  void rollback(void callback(ledger.Status status)) {
    _modification.clear();
    callback(rollbackStatus ?? ledger.Status.ok);
  }

  @override
  void getSnapshot(Object snapshotRequest, Uint8List keyPrefix, dynamic watcher,
      void callback(ledger.Status status)) {
    if (watcher != null) {
      _watcher = watcher;
    }
    callback(getSnapshotStatus ?? ledger.Status.ok);
  }

  List<ledger.Entry> getEntries(Uint8List keyPrefix) =>
      convertToEntries(_storageState.getEntries(keyPrefix));

  void onChange(Change change) {
    _watcher.onChange(
        new ledger.PageChange(
            timestamp: null,
            changedEntries: convertToEntries(change.changedEntries),
            deletedKeys: change.deletedKeys),
        ledger.ResultState.completed,
        ($fidl.InterfaceRequest<ledger.PageSnapshot> snapshotRequest) {});
  }
}
