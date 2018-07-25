// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class Node {
  final List<Node> childs = <Node>[];
  int parentsCount = 0;
  // [nodeId] must be unique among nodes in one computational graph.
  final String nodeId;

  Node(this.nodeId);

  List<int> get affectedInstances => <int>[];

  @override
  String toString() => nodeId;
}

class ModificationNode<T> extends Node {
  final int instanceId;
  final void Function(T) modification;

  ModificationNode(nodeId, this.instanceId, this.modification) : super(nodeId);

  @override
  List<int> get affectedInstances => [instanceId];
}

// TODO: consider to have both directed sync and bidirected sync.
class SynchronizationNode extends Node {
  final int instanceId1, instanceId2;

  SynchronizationNode(nodeId, this.instanceId1, this.instanceId2)
      : super(nodeId);

  @override
  List<int> get affectedInstances => [instanceId1, instanceId2];
}
