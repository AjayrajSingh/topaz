// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class Node {
  final List<Node> childs = <Node>[];
  int parentsCount = 0;

  List<int> get affectedInstances => <int>[];
}

class ModificationNode<T> extends Node {
  final int instanceId;
  final void Function(T) modification;

  ModificationNode(this.instanceId, this.modification);

  @override
  List<int> get affectedInstances => [instanceId];
}

// TODO: consider to have both directed sync and bidirected sync.
class SynchronizationNode extends Node {
  final int instanceId1, instanceId2;

  SynchronizationNode(this.instanceId1, this.instanceId2);

  @override
  List<int> get affectedInstances => [instanceId1, instanceId2];
}
