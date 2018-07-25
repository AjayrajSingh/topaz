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
      {bool allowPartial = false})
      : nodes = <Node>[] {
    final idToNode = new Map<String, Node>.fromIterable(graphNodes,
        key: (node) => node.nodeId);

    final setIds = ids.toSet();
    if (setIds.length != ids.length) {
      throw new FormatException('Elements of $ids should be unique');
    }

    if (!allowPartial && ids.length != graphNodes.length) {
      throw new FormatException(
          '$ids should contain all nodes from $graphNodes');
    }

    for (final id in ids) {
      final node = idToNode[id];
      if (node == null) {
        throw new FormatException(
            '$id is not an id of any node from $graphNodes');
      }
      nodes.add(node);
    }
  }

  @override
  String toString() {
    StringBuffer nodesString = new StringBuffer()
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
