// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'crdt_test_framework/crdt_test_framework.dart';
import 'helpers.dart';

class DocumentFleetFactory {
  final SledgeForTesting _sledge;
  final DocumentId _documentId;

  const DocumentFleetFactory(this._sledge, this._documentId);

  Fleet<Document> newFleet(int count) {
    return Fleet<Document>(
        count, (index) => _sledge.fakeGetDocument(_documentId));
  }
}

class NameLengthChecker extends Checker<Document> {
  @override
  void check(Document doc) {
    expect(doc['name'].value.length, equals(doc['length'].value));
  }
}

void main() async {
  setupLogger();

  final Schema nameLengthSchema = Schema(<String, BaseType>{
    'name': LastOneWinsString(),
    'length': Integer()
  });
  final documentId = DocumentId(nameLengthSchema);
  final fakeSledge = newSledgeForTesting()..startInfiniteTransaction();
  final documentFleetFactory = DocumentFleetFactory(fakeSledge, documentId);

  test('Document test with framework', () async {
    final fleet = documentFleetFactory.newFleet(3)
      ..runInTransaction(0, (Document doc) async {
        doc['name'].value = 'Alice';
        doc['length'].value = 5;
      })
      ..runInTransaction(1, (Document doc) async {
        doc['name'].value = 'Bob';
        doc['length'].value = 3;
      })
      ..runInTransaction(2, (Document doc) async {
        doc['name'].value = 'Carlos';
        doc['length'].value = 6;
      })
      ..synchronize([0, 1, 2])
      ..addChecker(() => NameLengthChecker());
    await fleet.testAllOrders();
  });

  test('Document. Stream', () async {
    final fleet = documentFleetFactory.newFleet(3);
    for (int id = 0; id < 3; id++) {
      fleet.runInTransaction(id, (Document cnt) async {
        expect(
            cnt.onChange,
            emitsInOrder([
              anything,
              anything,
              anything,
            ]));
      });
    }
    fleet
      ..runInTransaction(0, (Document doc) async {
        doc['name'].value = 'Alice';
      })
      ..synchronize([0, 1, 2])
      ..runInTransaction(1, (Document doc) async {
        doc['length'].value = 5;
      })
      ..synchronize([0, 1, 2])
      ..runInTransaction(1, (Document doc) async {
        doc['name'].value = 'Bob';
        doc['length'].value = 3;
      })
      ..synchronize([0, 1, 2]);
    await fleet.testSingleOrder();
  });
}
