// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'crdt_test_framework/crdt_test_framework.dart';
import 'helpers.dart';

class DocumentFleetFactory {
  final SledgeForTesting _sledge;
  final DocumentId _documentId;

  const DocumentFleetFactory(this._sledge, this._documentId);

  Fleet<Document> newFleet(int count) {
    return new Fleet<Document>(
        count, (index) => _sledge.fakeGetDocument(_documentId));
  }
}

class NameLengthChecker extends Checker<Document> {
  @override
  void check(dynamic doc) {
    expect(doc.name.value.length, equals(doc.length.value));
  }
}

void main() {
  final Schema nameLengthSchema = new Schema(<String, BaseType>{
    'name': new LastOneWinsString(),
    'length': new Integer()
  });
  final documentId = new DocumentId(nameLengthSchema);
  final fakeSledge = newSledgeForTesting()..startInfiniteTransaction();
  final documentFleetFactory = new DocumentFleetFactory(fakeSledge, documentId);

  test('Document test with framework', () {
    documentFleetFactory.newFleet(3)
      ..runInTransaction(0, (dynamic doc) {
        doc.name.value = 'Alice';
        doc.length.value = 5;
      })
      ..runInTransaction(1, (dynamic doc) {
        doc.name.value = 'Bob';
        doc.length.value = 3;
      })
      ..runInTransaction(2, (dynamic doc) {
        doc.name.value = 'Carlos';
        doc.length.value = 6;
      })
      ..synchronize([0, 1, 2])
      ..addChecker(() => new NameLengthChecker())
      ..testAllOrders();
  });
}
