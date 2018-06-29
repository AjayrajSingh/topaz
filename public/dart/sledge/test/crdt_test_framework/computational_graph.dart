// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'node.dart';

// Computational graph.
//
// This framework allows users to first specify a set of operations, and then run
// those operations in different orders. ComputationalGraph is used to specify
// this order relations between those operations, and to get correct orders of
// execution.
//
class ComputationalGraph {
  final List<Node> nodes = <Node>[];

  void addNode(Node v) {
    nodes.add(v);
  }

  void addRelation(Node parent, Node child) {
    child.parentsCount += 1;
    parent.childs.add(child);
  }

  int _countOrders() {
    // TODO: implement
    return 1;
  }

  List<Node> _getNthOrder(int index) {
    if (index < 0) {
      throw new ArgumentError.value(
          index, 'index', 'Index should be non negative.');
    }
    // TODO: implement
    if (index > 0) {
      throw new UnimplementedError(
          '_getNthOrder not implemented for index > 0.');
    }

    // TODO: should be replaced with general solution.
    // Get correct topological order.
    // Each time we take node with 0 in degree.
    List<Node> order = <Node>[];
    List<Node> ready = <Node>[];
    for (final node in nodes) {
      if (node.parentsCount == 0) {
        ready.add(node);
      }
    }

    Map<Node, int> known = <Node, int>{};
    while (ready.isNotEmpty) {
      Node cur = ready.removeLast();
      order.add(cur);

      for (final next in cur.childs) {
        known.putIfAbsent(next, () => next.parentsCount);
      }
      // Done in separate cycle to correctly manage situation when there are
      // duplicates in [cur.childs].
      for (final next in cur.childs) {
        known[next] -= 1;
        if (known[next] == 0) {
          ready.add(next);
        }
      }
    }
    return order;
  }

  // Returns all correct topological orders of this graph.
  Iterable<List<Node>> get orders =>
      new Iterable<List<Node>>.generate(_countOrders(), _getNthOrder);
}
