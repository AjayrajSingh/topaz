// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

class _FakeProxyController<T> extends ProxyController<T> {
  @override
  InterfaceRequest<T> request() {
    return null;
  }
}

/// Fake implementation of a PageSnapshot.
class FakeLedgerPageSnapshot extends ledger.PageSnapshotProxy {
  @override
  ProxyController<FakeLedgerPageSnapshot> get ctrl =>
      new _FakeProxyController<FakeLedgerPageSnapshot>();
}
