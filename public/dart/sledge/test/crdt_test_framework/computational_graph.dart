// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show Random;

import 'evaluation_order.dart';
import 'node.dart';

// Computational graph.
//
// This framework allows users to first specify a set of operations, and then run
// those operations in different orders. ComputationalGraph is used to specify
// the order between those operations, and to get correct orders of execution.
//
class ComputationalGraph {
  final List<Node> nodes = <Node>[];
  final List<List<int>> _allChoices = <List<int>>[];
  final Random random = Random(0);

  void addNode(Node v) {
    // TODO: remove O(n) part.
    // TODO: check that there is no insertions of different Nodes with the same
    // nodeId.
    if (nodes.contains(v)) {
      return;
    }
    nodes.add(v);
  }

  // Specifies that [parent] would be executed before [child].
  void addRelation(Node parent, Node child) {
    child.parentsCount += 1;
    parent.childs.add(child);
  }

  // Appends zeros to [choices] to contain [nodes.length] elements.
  void _padLength(List<int> choices) {
    while (choices.length < nodes.length) {
      choices.add(0);
    }
  }

  // Generates lexicographically next list of choices.
  // Returns true if generation was successful and false otherwise.
  bool _moveNextChoiceList(List<int> choices) {
    if (choices.isEmpty) {
      _padLength(choices);
      return true;
    }
    while (choices.isNotEmpty) {
      choices.last += 1;
      if (_getOrder(choices) == null) {
        choices.removeLast();
      } else {
        _padLength(choices);
        return true;
      }
    }
    return false;
  }

  int _countOrders() {
    _allChoices.clear();
    List<int> choices = <int>[];
    while (_moveNextChoiceList(choices)) {
      _allChoices.add(List<int>.from(choices));
    }
    return _allChoices.length;
  }

  // To generate a correct topological order, the following algorithm is used:
  //
  // Keep a list of nodes with zero input degree - [ready].
  // On each step:
  //  Choose an arbitrary [node] from [ready].
  //  Add [node] to order, and remove [node] from graph.
  //
  // List [choices] specifies which node to take from list on each step. Each
  // [choices[i]] should be greater or equal to 0 and less than the length of [ready]
  // at the begining of the step [i].

  // Returns [this] ordered topologically based on [choices].
  // Returns null if [choices] do not correspond to correct topological order.
  //
  // If [completeWithRandomChoices] is false, the first node will be used as a
  // choice when [choices] is over. Otherwise, nodes will be chosen randomly.
  EvaluationOrder _getOrder(List<int> choices,
      {bool completeWithRandomChoices = false}) {
    List<Node> order = <Node>[];
    List<Node> ready = <Node>[];
    for (final node in nodes) {
      if (node.parentsCount == 0) {
        ready.add(node);
      }
    }

    Map<Node, int> known = <Node, int>{};
    for (int i = 0; i < nodes.length; i++) {
      if (ready.isEmpty) {
        throw StateError('Computational graph should be acyclic.');
      }
      int curChoice = 0;
      if (i < choices.length) {
        curChoice = choices[i];
      } else if (completeWithRandomChoices) {
        curChoice = random.nextInt(ready.length);
      }
      if (curChoice >= ready.length) {
        return null;
      }
      Node cur = ready.removeAt(curChoice);
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
    return EvaluationOrder(order);
  }

  EvaluationOrder _getNthOrder(int index) {
    if (index < 0 || index >= _allChoices.length) {
      throw ArgumentError.value(index, 'index', 'Index is out of range.');
    }
    return _getOrder(_allChoices[index]);
  }

  EvaluationOrder getRandomOrder() =>
      _getOrder([], completeWithRandomChoices: true);

  // Returns all correct topological orders of this graph.
  Iterable<EvaluationOrder> get orders =>
      Iterable<EvaluationOrder>.generate(_countOrders(), _getNthOrder);
}
