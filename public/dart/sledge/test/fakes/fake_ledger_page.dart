// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

// ignore_for_file: implementation_imports, library_prefixes
import 'package:fidl/fidl.dart' as $fidl;
import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl_async.dart' as lib$fuchsia_mem;
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/key_value.dart';

import '../crdt_test_framework/storage_state.dart';
import 'fake_vmo.dart';

List<ledger.Entry> convertToEntries(final List<KeyValue> changedEntries) {
  final List<ledger.Entry> convertedEntries = <ledger.Entry>[];
  for (final keyValue in changedEntries) {
    convertedEntries.add(ledger.Entry(
        key: keyValue.key,
        value: lib$fuchsia_mem.Buffer(
            vmo: FakeVmo(keyValue.value), size: keyValue.value.length),
        priority: ledger.Priority(0)));
  }
  return convertedEntries;
}

class FakeLedgerPage extends ledger.PageProxy {
  StorageState _storageState;
  final Change _modification = Change();
  dynamic _watcher;

  FakeLedgerPage() {
    _storageState = StorageState(onChange);
  }

  StorageState get storageState => _storageState;

  @override
  Future<ledger.Status> put(Uint8List key, Uint8List value) async {
    _modification.changedEntries.add(KeyValue(key, value));
    return ledger.Status.ok;
  }

  @override
  Future<ledger.Status> delete(Uint8List key) async {
    _modification.deletedKeys.add(key);
    return ledger.Status.ok;
  }

  @override
  Future<ledger.Status> startTransaction() async {
    assert(_modification.changedEntries.isEmpty);
    assert(_modification.deletedKeys.isEmpty);
    return ledger.Status.ok;
  }

  @override
  Future<ledger.Status> commit() async {
    _storageState.applyChange(_modification);
    onChange(_modification);
    _modification.clear();
    return ledger.Status.ok;
  }

  @override
  Future<ledger.Status> rollback() async {
    _modification.clear();
    return ledger.Status.ok;
  }

  @override
  Future<ledger.Status> getSnapshot(Object snapshotRequest, Uint8List keyPrefix,
      $fidl.InterfaceHandle<ledger.PageWatcher> watcher) async {
    if (watcher != null) {
      _watcher = watcher;
    }
    return ledger.Status.ok;
  }

  List<ledger.Entry> getEntries(Uint8List keyPrefix) =>
      convertToEntries(_storageState.getEntries(keyPrefix));

  void onChange(Change change) {
    _watcher.onChange(
        ledger.PageChange(
            timestamp: null,
            changedEntries: convertToEntries(change.changedEntries),
            deletedKeys: change.deletedKeys),
        ledger.ResultState.completed);
  }
}
