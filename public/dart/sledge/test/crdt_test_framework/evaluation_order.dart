// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'node.dart';

/// Stores an order of nodes.
class EvaluationOrder {
  final List<Node> nodes;

  EvaluationOrder(this.nodes);

  /// Builds an EvaluationOrder that consists of [graphNodes] in the order given
  /// by [ids].
  ///
  /// All [ids] must be distinct. Each element of [ids] must be presented among
  /// nodeIds of [graphNodes]. If [allowPartial] is false, [ids] must contain
  /// nodeId for each node from [graphNodes].
  EvaluationOrder.fromIds(Iterable<String> ids, Iterable<Node> graphNodes,
      {bool allowPartial = false, allowGenerated = false})
      : nodes = <Node>[] {
    final idToNode = Map<String, Node>.fromIterable(graphNodes,
        key: (node) => node.nodeId);

    final setIds = ids.toSet();
    if (setIds.length != ids.length) {
      throw ArgumentError('Elements of ids ($ids) must be unique.');
    }

    if (!allowPartial) {
      for (final node in graphNodes) {
        if (!setIds.contains(node.nodeId)) {
          throw ArgumentError(
              'ids ($ids) must contain all nodes from `$graphNodes`.');
        }
      }
    }

    for (final id in ids) {
      Node node = idToNode[id];
      if (node == null) {
        if (!allowGenerated || !id.startsWith('g-')) {
          throw ArgumentError(
              '`$id` is not an id of a node from `$graphNodes`.');
        }
        // Can throw FormatException
        int firstDash = 1;
        int underscore = id.indexOf('_');
        int secondDash = id.indexOf('-', underscore + 1);
        int id1 = int.parse(id.substring(firstDash + 1, underscore));
        int id2 = int.parse(id.substring(underscore + 1, secondDash));
        node = SynchronizationNode.generated(
            id.substring(secondDash + 1), id1, id2);
      }
      nodes.add(node);
    }
  }

  @override
  String toString() {
    StringBuffer nodesString = StringBuffer()
      ..writeAll(nodes.map((node) => "'$node'"), ', ');
    return '[$nodesString]';
  }

  @override
  int get hashCode {
    // TODO: implement hashCode with better collision rate.
    return 0;
  }

  /// Compares nodes by nodeId.
  @override
  bool operator ==(dynamic other) {
    if (nodes.length != other.nodes.length) {
      return false;
    }
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].nodeId != other.nodes[i].nodeId) {
        return false;
      }
    }
    return true;
  }
}
