// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'checker.dart';
import 'computational_graph.dart';
import 'evaluation_order.dart';
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

typedef CheckerGenerator<T> = Checker<T> Function();

/// Fleet of instances.
class Fleet<T extends dynamic> {
  int _fleetSize;
  List<Node> _lastModifications;
  final Node _initialModification = new Node('init');
  final ComputationalGraph graph = new ComputationalGraph();
  final T Function(int) _instanceGenerator;
  final List<CheckerGenerator<T>> _checkerGenerators = <CheckerGenerator<T>>[];

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
  // (1, 2) (2, 3) ... (k-1, k) (k, k-2) (k-2, k-3) ... (3, 2) (2, 1)
  // And adds them into the computational graph. Each two consecutive
  // synchronizations share a node. So their order is fixed in the graph.
  // (k, k-2) (k-2, k-3) ... (3, 2) (2, 1) are necessary to back propagate the
  // changes made in `k`.
  void synchronize(List<int> group) {
    if (group.length <= 1) {
      return;
    }
    final list = <int>[]..addAll(group)..addAll(group.reversed.skip(2));
    for (int i = 0; i < list.length - 1; i++) {
      Node node = new SynchronizationNode(
          's${list[i]}_${list[i + 1]}_n${graph.nodes.length}',
          list[i],
          list[i + 1]);
      _addNode(node, list[i]);
      _addNode(node, list[i + 1]);
    }
  }

  void runInTransaction(int id, void Function(T) modification) {
    final node = new ModificationNode<T>(
        'm${id}_n${graph.nodes.length}', id, modification);
    _addNode(node, id);
  }

  void addChecker(CheckerGenerator<T> checkerGenerator) =>
      _checkerGenerators.add(checkerGenerator);

  void _testSingleOrder(EvaluationOrder order) {
    final fleetState = new FleetState<T>(_fleetSize, _instanceGenerator);
    for (final newChecker in _checkerGenerators) {
      fleetState.addChecker(newChecker());
    }

    for (int i = 0; i < order.nodes.length; i++) {
      fleetState.applyNode(order.nodes[i], i);
    }
  }

  void testFixedOrder(List<String> nodeIds, {bool allowPartial = false}) =>
      _testSingleOrder(new EvaluationOrder.fromIds(nodeIds, graph.nodes,
          allowPartial: allowPartial));

  void testSingleOrder() => _testSingleOrder(graph.orders.first);

  void testAllOrders() => graph.orders.forEach(_testSingleOrder);
}
