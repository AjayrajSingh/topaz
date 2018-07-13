// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

class FakeLedgerPage extends ledger.PageProxy {
  ledger.Status putCallback;
  ledger.Status deleteCallback;
  ledger.Status startTransactionCallback;
  ledger.Status commitCallback;
  ledger.Status rollbackCallback;
  ledger.Status getSnapshotCallback;

  void resetAllCallbacks() {
    putCallback = null;
    deleteCallback = null;
    startTransactionCallback = null;
    commitCallback = null;
    rollbackCallback = null;
    getSnapshotCallback = null;
  }

  @override
  void put(
      Uint8List key, Uint8List value, void callback(ledger.Status status)) {
    callback(putCallback ?? ledger.Status.ok);
  }

  @override
  void delete(Uint8List key, void callback(ledger.Status status)) {
    callback(deleteCallback ?? ledger.Status.ok);
  }

  @override
  void startTransaction(void callback(ledger.Status status)) {
    callback(startTransactionCallback ?? ledger.Status.ok);
  }

  @override
  void commit(void callback(ledger.Status status)) {
    callback(commitCallback ?? ledger.Status.ok);
  }

  @override
  void rollback(void callback(ledger.Status status)) {
    callback(rollbackCallback ?? ledger.Status.ok);
  }

  @override
  void getSnapshot(Object snapshotRequest, Uint8List keyPrefix, Object watcher,
      void callback(ledger.Status status)) {
    callback(getSnapshotCallback ?? ledger.Status.ok);
  }
}
