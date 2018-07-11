// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: prefer_initializing_formals

// ignore_for_file: implementation_imports

import 'package:sledge/sledge.dart';
import 'package:sledge/src/transaction.dart';

import 'fakes/fake_ledger_object_factories.dart';
import 'fakes/fake_ledger_page.dart';

class SledgeForTesting extends Sledge {
  FakeLedgerPage fakeLedgerPage;
  Transaction _fakeTransaction;

  SledgeForTesting(FakeLedgerPage fakeLedgerPage,
      FakeLedgerPageSnapshotFactory fakeLedgerPageSnapshotFactory)
      : fakeLedgerPage = fakeLedgerPage,
        super.testing(fakeLedgerPage, fakeLedgerPageSnapshotFactory);

  Document fakeGetDocument(DocumentId documentId) {
    return new Document(this, documentId);
  }

  @override
  Transaction get currentTransaction {
    return _fakeTransaction ?? super.currentTransaction;
  }

  void startInfiniteTransaction() {
    _fakeTransaction = new Transaction(null, null);
  }
}

SledgeForTesting newSledgeForTesting() {
  return new SledgeForTesting(
      new FakeLedgerPage(), new FakeLedgerPageSnapshotFactory());
}
