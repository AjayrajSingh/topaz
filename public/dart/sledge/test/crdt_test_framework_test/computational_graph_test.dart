// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:test/test.dart';

import '../crdt_test_framework/computational_graph.dart';
import '../crdt_test_framework/node.dart';

class NamedNode extends Node {
  String name = '';

  NamedNode(this.name);

  @override
  String toString() => name;
}

void main() {
  test('Build and get orders.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new NamedNode('n 1');
    final n2 = new NamedNode('n 2');
    final n3 = new NamedNode('n 3');
    final n4 = new NamedNode('n 4');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addNode(n4)
      ..addRelation(n1, n2)
      ..addRelation(n2, n3)
      ..addRelation(n2, n4);

    final orders = G.orders.toList();
    expect(orders.length, equals(2));
    expect(
        orders,
        containsAll([
          [n1, n2, n3, n4],
          [n1, n2, n4, n3]
        ]));
  });

  test('Build and get orders not connected.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new NamedNode('n 1');
    final n2 = new NamedNode('n 2');
    final n3 = new NamedNode('n 3');
    G
      ..addNode(n1)
      ..addNode(n2)
      ..addNode(n3)
      ..addRelation(n2, n3);

    final orders = G.orders.toList();
    expect(orders.length, equals(3));
    expect(
        orders,
        containsAll([
          [n1, n2, n3],
          [n2, n1, n3],
          [n2, n3, n1]
        ]));
  });

  test('Build and get orders, cyclic graph.', () {
    ComputationalGraph G = new ComputationalGraph();
    final n1 = new NamedNode('n 1');
    final n2 = new NamedNode('n 2');
    final n3 = new NamedNode('n 3');
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
