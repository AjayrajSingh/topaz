// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

class FakeLedgerPage extends ledger.PageProxy {
  @override
  void put(
      Uint8List key, Uint8List value, void callback(ledger.Status status)) {
    callback(ledger.Status.ok);
  }

  @override
  void delete(Uint8List key, void callback(ledger.Status status)) {
    callback(ledger.Status.ok);
  }

  @override
  void startTransaction(void callback(ledger.Status status)) {
    callback(ledger.Status.ok);
  }

  @override
  void commit(void callback(ledger.Status status)) {
    callback(ledger.Status.ok);
  }

  @override
  void rollback(void callback(ledger.Status status)) {
    callback(ledger.Status.ok);
  }
}
