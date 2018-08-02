// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

class FakeLedgerPage extends ledger.PageProxy {
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

  @override
  void put(
      Uint8List key, Uint8List value, void callback(ledger.Status status)) {
    callback(putStatus ?? ledger.Status.ok);
  }

  @override
  void delete(Uint8List key, void callback(ledger.Status status)) {
    callback(deleteStatus ?? ledger.Status.ok);
  }

  @override
  void startTransaction(void callback(ledger.Status status)) {
    callback(startTransactionStatus ?? ledger.Status.ok);
  }

  @override
  void commit(void callback(ledger.Status status)) {
    callback(commitStatus ?? ledger.Status.ok);
  }

  @override
  void rollback(void callback(ledger.Status status)) {
    callback(rollbackStatus ?? ledger.Status.ok);
  }

  @override
  void getSnapshot(Object snapshotRequest, Uint8List keyPrefix, Object watcher,
      void callback(ledger.Status status)) {
    callback(getSnapshotStatus ?? ledger.Status.ok);
  }
}
