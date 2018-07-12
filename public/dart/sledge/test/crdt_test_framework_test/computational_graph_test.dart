// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:test/test.dart';

import '../crdt_test_framework/computational_graph.dart';
import '../crdt_test_framework/evaluation_order.dart';
import '../crdt_test_framework/node.dart';

void main() {
  test('Build and get orders.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new Node('n 1');
    final n2 = new Node('n 2');
    final n3 = new Node('n 3');
    final n4 = new Node('n 4');
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
          new EvaluationOrder([n1, n2, n3, n4]),
          new EvaluationOrder([n1, n2, n4, n3])
        ]));
  });

  test('Build and get orders not connected.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new Node('n 1');
    final n2 = new Node('n 2');
    final n3 = new Node('n 3');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addRelation(n2, n3);

    final orders = G.orders.toList();
    expect(
        orders,
        unorderedEquals([
          new EvaluationOrder([n1, n2, n3]),
          new EvaluationOrder([n2, n1, n3]),
          new EvaluationOrder([n2, n3, n1])
        ]));
  });

  test('Build and get orders.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new Node('n 1');
    final n2 = new Node('n 2');
    final n3 = new Node('n 3');
    final n4 = new Node('n 4');
    final n5 = new Node('n 5');
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
          new EvaluationOrder([n1, n2, n3, n4, n5]),
          new EvaluationOrder([n1, n2, n4, n3, n5]),
          new EvaluationOrder([n1, n4, n2, n3, n5])
        ]));
  });

  test('Build and get orders, cyclic graph.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new Node('n 1');
    final n2 = new Node('n 2');
    final n3 = new Node('n 3');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n3, n1);

    expect(() => G.orders, throwsStateError);
  });
}
