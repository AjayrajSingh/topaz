// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;

import 'package:test/test.dart';

import 'checker.dart';
import 'computational_graph.dart';
import 'evaluation_order.dart';
import 'fleet_state.dart';
import 'node.dart';
import 'single_order_test_failure.dart';

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
  final Node _initialModification = Node('init');
  final ComputationalGraph graph = ComputationalGraph();
  final T Function(int) _instanceGenerator;
  final List<CheckerGenerator<T>> _checkerGenerators = <CheckerGenerator<T>>[];
  double _expectedSyncsPerAction = 0.0;
  final Random random = Random(1);

  Fleet(this._fleetSize, this._instanceGenerator) {
    _lastModifications =
        List<Node>.filled(_fleetSize, _initialModification);
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
      Node node = SynchronizationNode(
          '${list[i]}_${list[i + 1]}-n${graph.nodes.length}',
          list[i],
          list[i + 1]);
      _addNode(node, list[i]);
      _addNode(node, list[i + 1]);
    }
  }

  void runInTransaction(int id, Future Function(T) modification) {
    final node =
        ModificationNode<T>('$id-n${graph.nodes.length}', id, modification);
    _addNode(node, id);
  }

  /// Adds checker that would be called after execution of each node, including
  /// randomly generated synchronization nodes.
  void addChecker(CheckerGenerator<T> checkerGenerator) {
    _checkerGenerators.add(checkerGenerator);
  }

  /// Sets the expected amount of random synchronizations after execution of
  /// each node, excluding randomly generated synchronization nodes, to
  /// [expectedSyncsPerAction].
  void setRandomSynchronizationsRate(double expectedSyncsPerAction) {
    if (expectedSyncsPerAction < 0) {
      throw ArgumentError(
          'Number of synchronizations must be greater or equal to 0. Got $expectedSyncsPerAction.');
    }
    _expectedSyncsPerAction = expectedSyncsPerAction;
  }

  /// Executes the operations in all nodes in a given [order]. If [order] is not
  /// specified, execute all nodes in some fixed order, that would be same over
  /// all calls.
  Future testSingleOrder(
      {EvaluationOrder order, bool enableRandomSyncronization = true}) async {
    order ??= graph.orders.first;
    final fleetState = FleetState<T>(_fleetSize, _instanceGenerator);
    for (final newChecker in _checkerGenerators) {
      fleetState.addChecker(newChecker());
    }

    // [completedOrder] contains all nodes from [order] in the same order, and
    // additional randomly generated synchronization nodes.
    EvaluationOrder completedOrder = order;
    if (enableRandomSyncronization &&
        _fleetSize > 1 &&
        _expectedSyncsPerAction > 0) {
      completedOrder = EvaluationOrder([]);
      for (final node in order.nodes) {
        completedOrder.nodes.add(node);
        // Geometric distribution (the probability distribution of the number Y
        // of failures before the first success) is used to generate a number of
        // synchronization nodes:
        //    E(Y) = (1 - p) / p
        // So for fixed E(Y):
        //    p = 1 / (1 + E(Y))
        while (random.nextDouble() >= 1.0 / (1.0 + _expectedSyncsPerAction)) {
          // To generate equiprobably a pair of different ids from
          // range [0, _fleetSize):
          //  - generate equiprobably id1 from [0, _fleetSize)
          //  - generate equiprobably id2 from [0, _fleetSize)\{id1}
          int instanceId1 = random.nextInt(_fleetSize);
          int instanceId2 = random.nextInt(_fleetSize - 1);
          if (instanceId2 >= instanceId1) {
            instanceId2++;
          }
          completedOrder.nodes.add(SynchronizationNode.generated(
              '${completedOrder.nodes.length}', instanceId1, instanceId2));
        }
      }
    }

    for (int i = 0; i < completedOrder.nodes.length; i++) {
      try {
        await fleetState.applyNode(completedOrder.nodes[i], i);
      } on TestFailure catch (failure) {
        // ignore: only_throw_errors
        throw SingleOrderTestFailure(
            failure, completedOrder, completedOrder.nodes[i]);
      }
    }
  }

  /// Executes the operations in all nodes in an order specified by [nodeIds].
  /// If [allowPartial] is false, checks that all [graph] nodes are present in
  /// [nodeIds].
  /// If [allowGenerated] is false, throws an Error when [nodeIds] contains id
  /// of randomly generated synchronization node.
  ///
  /// It can be used to reproduce previous execution order with an information
  /// from TestFailure message.
  Future testFixedOrder(Iterable<String> nodeIds,
      {bool allowPartial = false, bool allowGenerated = true}) async {
    await testSingleOrder(
        order: EvaluationOrder.fromIds(nodeIds, graph.nodes,
            allowPartial: allowPartial, allowGenerated: allowGenerated),
        enableRandomSyncronization: false);
  }

  /// Executes the operations in all nodes in [count] random orders.
  ///
  /// On each step a random node is chosen to be executed equiprobably from
  /// nodes available to execution. Note that this algorithm does not provide
  /// equiprobable distribution over all correct execution orders.
  Future testRandomOrders(int count) async {
    for (int i = 0; i < count; i++) {
      await testSingleOrder(order: graph.getRandomOrder());
    }
  }

  Future testAllOrders() async {
    for (final order in graph.orders) {
      await testSingleOrder(order: order);
    }
  }
}
