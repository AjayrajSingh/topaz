// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'computational_graph.dart';
import 'fleet_state.dart';
import 'node.dart';

// Sledge is supposed to work with multiple connections, and order of operations
// and synchronization is unpredictable. It’s hard to cover all cases by tests
// manually.
//
// This framework should allow to write a generic tests. So that developer may
// write one test description and framework would evaluate different scenarios
// of execution.
//
// Framework should allow to write tests on different layers of Sledge:
//  - layer of data types
//  - layer of documents
//  - layer of Sledge
//
// To run different scenarios, we build a computational DAG (directed acyclic
// graph). And each topological sort of that graph is a correct evaluation order.
//
// All operations that are related to a single node are ordered. Relation
// between operations on different nodes based on synchronization operations.
//
/// Fleet of instances.
class Fleet<T extends dynamic> {
  int _fleetSize;
  List<Node> _lastModifications;
  final Node _initialModification = new Node();
  final ComputationalGraph graph = new ComputationalGraph();
  T Function(int) _instanceGenerator;

  Fleet(this._fleetSize, this._instanceGenerator) {
    _lastModifications =
        new List<Node>.filled(_fleetSize, _initialModification);
    graph.addNode(_initialModification);
  }

  void _addNode(Node node, int id) {
    graph
      ..addNode(node)
      ..addRelation(_lastModifications[id], node);
    _lastModifications[id] = node;
  }

  // Perform synchronization of [group] of instances, specified by ids.
  // It builds a chain of pairwise synchronization:
  // (1, 2) (2, 3) ... (k-1, k) (k, k-1) ... (3, 2) (2, 1)
  // And adds them into the computational graph. Each two consecutive
  // synchronizations share a node. So their order is fixed in the graph.
  void synchronize(List<int> group) {
    if (group.isEmpty) {
      return;
    }
    final list = <int>[]
      ..addAll(group)
      ..removeLast()
      ..addAll(group.reversed);
    for (int i = 0; i < list.length - 1; i++) {
      Node node = new SynchronizationNode(list[i], list[i + 1]);
      _addNode(node, list[i]);
      _addNode(node, list[i + 1]);
    }
  }

  void runInTransaction(int id, void Function(T) modification) {
    final node = new ModificationNode<T>(id, modification);
    _addNode(node, id);
  }

  void testSingleOrder() {
    final fleetState = new FleetState<T>(_fleetSize, _instanceGenerator);

    final order = graph.orders.first;
    for (int i = 0; i < order.length; i++) {
      fleetState.applyNode(order[i], i);
    }
  }
}
