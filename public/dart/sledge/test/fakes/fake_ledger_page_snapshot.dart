// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

import 'fake_ledger_page.dart';

class _FakeProxyController<T> extends AsyncProxyController<T> {
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
  AsyncProxyController<FakeLedgerPageSnapshot> get ctrl =>
      _FakeProxyController<FakeLedgerPageSnapshot>();

  @override
  Future<ledger.PageSnapshot$GetEntries$Response> getEntries(
      Uint8List keyStart, ledger.Token token) async {
    final response = ledger.PageSnapshot$GetEntries$Response(
        ledger.IterationStatus.ok, _fakeLedgerPage.getEntries(keyStart), token);
    return response;
  }
}
