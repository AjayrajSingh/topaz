// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: prefer_initializing_formals

import 'package:sledge/sledge.dart';

import 'fakes/fake_ledger_object_factories.dart';
import 'fakes/fake_ledger_page.dart';

class SledgeForTesting extends Sledge {
  FakeLedgerPage fakeLedgerPage;

  SledgeForTesting(FakeLedgerPage fakeLedgerPage,
      FakeLedgerPageSnapshotFactory fakeLedgerPageSnapshotFactory)
      : fakeLedgerPage = fakeLedgerPage,
        super.testing(fakeLedgerPage, fakeLedgerPageSnapshotFactory);
}

SledgeForTesting newSledgeForTesting() {
  return new SledgeForTesting(
      new FakeLedgerPage(), new FakeLedgerPageSnapshotFactory());
}
