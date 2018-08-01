// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import 'fake_ledger_page.dart';

class _FakeProxyController<T> extends ProxyController<T> {
  @override
  InterfaceRequest<T> request() {
    return null;
  }
}

/// Fake implementation of a PageSnapshot.
class FakeLedgerPageSnapshot extends ledger.PageSnapshotProxy {
  FakeLedgerPage _fakeLedgerPage;

  FakeLedgerPageSnapshot(this._fakeLedgerPage);

  @override
  ProxyController<FakeLedgerPageSnapshot> get ctrl =>
      new _FakeProxyController<FakeLedgerPageSnapshot>();

  @override
  void getEntries(
      Uint8List keyPrefix,
      ledger.Token token,
      void callback(ledger.Status status, List<ledger.Entry> entriesResult,
          ledger.Token nextTokenResult)) {
    callback(ledger.Status.ok, _fakeLedgerPage.getEntries(keyPrefix), token);
  }
}
