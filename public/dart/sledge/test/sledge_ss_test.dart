// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

import 'crdt_test_framework/crdt_test_framework.dart';
import 'helpers.dart';

class SledgeFleetFactory {
  Fleet<Sledge> newFleet(int count) {
    return Fleet<Sledge>(count, (index) => newSledgeForTesting());
  }
}

void main() async {
  final Schema nameSchema = Schema(<String, BaseType>{
    'name': LastOneWinsString(),
  });
  final documentId = DocumentId(nameSchema);

  final sledgeFleetFactory = SledgeFleetFactory();

  test('Sledge test with framework. One instance.', () async {
    final fleet = sledgeFleetFactory.newFleet(1)
      ..runInTransaction(0, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        doc['name'].value = 'Alice';
      })
      ..runInTransaction(0, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        expect(doc['name'].value, equals('Alice'));
      });
    await fleet.testSingleOrder();
  });

  test('Sledge test with framework. Two instances.', () async {
    final fleet = sledgeFleetFactory.newFleet(2)
      ..runInTransaction(0, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        doc['name'].value = 'Alice';
      })
      ..synchronize([0, 1])
      ..runInTransaction(1, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        expect(doc['name'].value, equals('Alice'));
      });
    await fleet.testSingleOrder();
  });

  test('Sledge test with framework. Two instances. Updates.', () async {
    final fleet = sledgeFleetFactory.newFleet(2)
      ..runInTransaction(0, (Sledge sledge) async {
        await sledge.getDocument(documentId);
      })
      ..runInTransaction(1, (Sledge sledge) async {
        await sledge.getDocument(documentId);
      })
      // At this point the document is stored in memory for both instances.
      // Updates on one document will be transmitted to the other document via
      // PageWatcher.onChange.
      ..runInTransaction(0, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        doc['name'].value = 'Alice';
      })
      ..synchronize([0, 1])
      ..runInTransaction(1, (Sledge sledge) async {
        Document doc = await sledge.getDocument(documentId);
        expect(doc['name'].value, equals('Alice'));
      });
    await fleet.testSingleOrder();
  });
}
