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
  final FakeLedgerPage fakeLedgerPage;
  Transaction _fakeTransaction;

  SledgeForTesting(FakeLedgerPage fakeLedgerPage)
      : fakeLedgerPage = fakeLedgerPage,
        super.testing(
            fakeLedgerPage, FakeLedgerObjectsFactory(fakeLedgerPage));

  Document fakeGetDocument(DocumentId documentId) {
    return Document(this, documentId);
  }

  @override
  Transaction get currentTransaction {
    return _fakeTransaction ?? super.currentTransaction;
  }

  void startInfiniteTransaction() {
    _fakeTransaction =
        Transaction(null, null, FakeLedgerObjectsFactory(null));
  }
}

SledgeForTesting newSledgeForTesting() {
  return SledgeForTesting(FakeLedgerPage());
}
