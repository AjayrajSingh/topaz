// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:test/test.dart';
import 'package:sledge/src/document/values/map_value.dart';

import '../crdt_test_framework/crdt_test_framework.dart';
import '../crdt_test_framework/evaluation_order.dart';

// Wraps the construction of Fleet of PosNegCounter.
class MapFleetFactory<K, V> {
  const MapFleetFactory();

  Fleet<MapValue<K, V>> newFleet(int count) {
    return new Fleet<MapValue<K, V>>(count, (index) => new MapValue<K, V>());
  }
}

const MapFleetFactory<int, int> intMapFleetFactory =
    const MapFleetFactory<int, int>();

class ValuesAreUniqueChecker<K, V> extends Checker<MapValue<K, V>> {
  @override
  void check(Map<K, V> m) {
    final valueSet = m.values.toSet();
    expect(m.values.length, equals(valueSet.length));
  }
}

void main() async {
  test('Checker fails.', () async {
    final fleet = intMapFleetFactory.newFleet(2)
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[1] = 2;
      })
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[2] = 4;
      })
      ..runInTransaction(1, (MapValue<int, int> m1) async {
        m1[1] = 4;
        m1[2] = 2;
      })
      ..synchronize([0, 1])
      ..addChecker(() => new ValuesAreUniqueChecker<int, int>());
    try {
      await fleet.testAllOrders();
      // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
      // throw another exception, not caught in the following code.
      fail('Expected testAllOrders to fail.');
    } on SingleOrderTestFailure catch (failure) {
      final nodeIds = failure.order.nodes.map((node) => node.nodeId);
      // Check that the EvaluationOrder is correctly reproduced with the list of
      // nodeIds.
      expect(new EvaluationOrder.fromIds(nodeIds, fleet.graph.nodes),
          equals(failure.order));

      try {
        await fleet.testSingleOrder(failure.order);
        // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
        // throw another exception, not caught in the following code.
        fail('Expected testSingleOrder to fail.');
      } on SingleOrderTestFailure catch (secondFailure) {
        expect(secondFailure.order, equals(failure.order));
      }
    }
  });
}
