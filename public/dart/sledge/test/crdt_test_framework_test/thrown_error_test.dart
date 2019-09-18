// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';
import '../crdt_test_framework/evaluation_order.dart';

// Wraps the construction of Fleet of PosNegCounter.
class MapFleetFactory<K, V> {
  const MapFleetFactory();

  Fleet<MapValue<K, V>> newFleet(int count) {
    return Fleet<MapValue<K, V>>(count, (index) => MapValue<K, V>());
  }
}

const MapFleetFactory<int, int> intMapFleetFactory =
    MapFleetFactory<int, int>();

class ValuesAreUniqueChecker<K, V> extends Checker<MapValue<K, V>> {
  @override
  void check(Map<K, V> m) {
    final valueSet = m.values.toSet();
    expect(m.values.length, equals(valueSet.length));
  }
}

void main() async {
  setupLogger();

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
      ..addChecker(() => ValuesAreUniqueChecker<int, int>());
    try {
      await fleet.testAllOrders();
      // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
      // throw another exception, not caught in the following code.
      fail('Expected testAllOrders to fail.');
    } on SingleOrderTestFailure catch (failure) {
      final nodeIds = failure.order.nodes.map((node) => node.nodeId);
      // Check that the EvaluationOrder is correctly reproduced with the list of
      // nodeIds.
      expect(EvaluationOrder.fromIds(nodeIds, fleet.graph.nodes),
          equals(failure.order));

      try {
        await fleet.testSingleOrder(order: failure.order);
        // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
        // throw another exception, not caught in the following code.
        fail('Expected testSingleOrder to fail.');
      } on SingleOrderTestFailure catch (secondFailure) {
        expect(secondFailure.order, equals(failure.order));
      }
    }
  });

  test('Checker fails. Random orders. Random sync.', () async {
    final fleet = intMapFleetFactory.newFleet(2)
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[1] = 2;
      })
      ..synchronize([0, 1])
      ..runInTransaction(1, (MapValue<int, int> m1) async {
        m1[1] = 4;
        m1[2] = 2;
      })
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[2] = 4;
      })
      ..setRandomSynchronizationsRate(1.0)
      ..addChecker(() => ValuesAreUniqueChecker<int, int>());
    try {
      // 1/2 probability of the correct order.
      // 1/2 probability of synchronization after the last modification.
      // In average, an exception is thrown every 4 runs.
      // With a 100 runs, the probability of not having an exception thrown is:
      // (3/4)^100 < 3.21e-13
      await fleet.testRandomOrders(100);
      // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
      // throw another exception, not caught in the following code.
      fail('Expected testRandomOrders to fail.');
    } on SingleOrderTestFailure catch (failure) {
      final nodeIds = failure.order.nodes.map((node) => node.nodeId);
      // Check that the EvaluationOrder is correctly reproduced with the list of
      // nodeIds.
      expect(
          EvaluationOrder.fromIds(nodeIds, fleet.graph.nodes,
              allowGenerated: true),
          equals(failure.order));

      // Check that generated synchronization nodes are also reproduced.
      //
      // If we only keep the order and choose synchronizations randomly,
      // the probability of throwing TestFailure is 1/2.
      // So probability to throw TestFailure 20 times in a row is < 1e-6
      for (int it = 0; it < 20; it++) {
        try {
          await fleet
              .testFixedOrder(failure.order.nodes.map((node) => node.nodeId));
          // If SingleOrderTestFailure wasn't thrown, fail. Note that fail will
          // throw another exception, not caught in the following code.
          fail('Expected testFixedOrder to fail.');
        } on SingleOrderTestFailure catch (doublingFailure) {
          expect(doublingFailure.order, equals(failure.order));
        }
      }
    }
  });
}
