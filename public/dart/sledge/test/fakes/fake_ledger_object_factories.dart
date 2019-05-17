// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
// ignore: implementation_imports
import 'package:sledge/src/ledger_helpers.dart';

import 'fake_ledger_page.dart';
import 'fake_ledger_page_snapshot.dart';
import 'fake_ledger_page_watcher_binding.dart';

/// Fake implementation of LedgerObjectsFactory.
class FakeLedgerObjectsFactory implements LedgerObjectsFactory {
  final FakeLedgerPage _fakeLedgerPage;

  FakeLedgerObjectsFactory(this._fakeLedgerPage);

  @override
  ledger.PageWatcherBinding newPageWatcherBinding() => FakePageWatcherBinding();

  @override
  ledger.PageSnapshotProxy newPageSnapshotProxy() =>
      FakeLedgerPageSnapshot(_fakeLedgerPage);
}
