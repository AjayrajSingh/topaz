// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
// ignore: implementation_imports
import 'package:sledge/src/ledger_helpers.dart';

import 'fake_ledger_page_snapshot.dart';

/// Fake implementation of LedgerPageSnapshotFactory.
class FakeLedgerPageSnapshotFactory implements LedgerPageSnapshotFactory {
  @override
  ledger.PageSnapshotProxy newInstance() {
    return new FakeLedgerPageSnapshot();
  }
}
