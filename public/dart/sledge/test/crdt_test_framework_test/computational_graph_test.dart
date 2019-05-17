// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/computational_graph.dart';
import '../crdt_test_framework/evaluation_order.dart';
import '../crdt_test_framework/node.dart';

void main() {
  setupLogger();

  test('Build and get orders.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    final n4 = Node('4');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addNode(n4)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n2, n4);

    final orders = G.orders.toList();
    expect(
        orders,
        unorderedEquals([
          EvaluationOrder([n1, n2, n3, n4]),
          EvaluationOrder([n1, n2, n4, n3])
        ]));
  });

  test('Build and get orders not connected.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addRelation(n2, n3);

    final orders = G.orders.toList();
    expect(
        orders,
        unorderedEquals([
          EvaluationOrder([n1, n2, n3]),
          EvaluationOrder([n2, n1, n3]),
          EvaluationOrder([n2, n3, n1])
        ]));
  });

  test('Build and get orders.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    final n4 = Node('4');
    final n5 = Node('5');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addNode(n4)
      ..addNode(n5)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n1, n4)
      ..addRelation(n3, n5)
      ..addRelation(n4, n5);

    final orders = G.orders.toList();
    expect(
        orders,
        unorderedEquals([
          EvaluationOrder([n1, n2, n3, n4, n5]),
          EvaluationOrder([n1, n2, n4, n3, n5]),
          EvaluationOrder([n1, n4, n2, n3, n5])
        ]));
  });

  test('Build and get orders, cyclic graph.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n3, n1);

    expect(() => G.orders, throwsStateError);
  });

  test('Check that random orders differs.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    G..addNode(n1)..addNode(n2);
    final orders = <EvaluationOrder>[];
    for (int i = 0; i < 31; i++) {
      orders.add(G.getRandomOrder());
    }
    // Probability of each order is 1/2. So probability that in 31 cases orders
    // would be the same is 2(1/2)^31 = (1/2)^30 < 1e-9.
    expect(
        orders,
        containsAll([
          EvaluationOrder([n1, n2]),
          EvaluationOrder([n2, n1])
        ]));
  });

  test('Check getRandomOrder in linear graph.', () {
    ComputationalGraph G = ComputationalGraph();
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    final n4 = Node('4');
    final n5 = Node('5');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addNode(n4)
      ..addNode(n5)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n3, n4)
      ..addRelation(n4, n5);

    final order = G.getRandomOrder();
    expect(order, equals(EvaluationOrder([n1, n2, n3, n4, n5])));
  });
}
