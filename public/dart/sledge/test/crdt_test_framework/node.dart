// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

class Node {
  final List<Node> childs = <Node>[];
  int parentsCount = 0;
  // [nodeId] must be unique among nodes in one computational graph.
  final String nodeId;

  /// Manual Node constructor. Adds prefix 'n-' to [nodeId].
  Node(String nodeId) : this._internal('n-$nodeId');

  /// Constructor, doesn't modify [nodeId]. It's expected that [nodeId]
  /// already contains type prefix.
  Node._internal(this.nodeId) {
    if (nodeId.contains("'")) {
      throw ArgumentError("[nodeId] should not contain character <'>.");
    }
    if (nodeId.startsWith(r'[\w]+-')) {
      throw ArgumentError('[nodeId] should start with the type prefix.');
    }
  }

  List<int> get affectedInstances => <int>[];

  @override
  String toString() => nodeId;
}

// ignore_for_file: prefer_initializing_formals
class ModificationNode<T> extends Node {
  final int instanceId;
  final Future Function(T) modification;

  ModificationNode(String nodeId, this.instanceId, this.modification)
      : super._internal('m-$nodeId');

  @override
  List<int> get affectedInstances => [instanceId];
}

// TODO: consider to have both directed sync and bidirected sync.
class SynchronizationNode extends Node {
  final int instanceId1, instanceId2;

  SynchronizationNode(String nodeId, this.instanceId1, this.instanceId2)
      : super._internal('s-$nodeId');

  SynchronizationNode.generated(String nodeId, instanceId1, instanceId2)
      : instanceId1 = instanceId1,
        instanceId2 = instanceId2,
        super._internal('g-${instanceId1}_$instanceId2-$nodeId');

  @override
  List<int> get affectedInstances => [instanceId1, instanceId2];
}
