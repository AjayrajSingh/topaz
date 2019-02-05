// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import '../surface/surface.dart';
import '../surface/surface_relation.dart';

/// Simple mutable SurfaceNode data structure
class SurfaceNode extends Iterable<SurfaceNode> {
  /// Construct [SurfaceNode] - holds a Surface, where the relationships
  /// described in the Surface are between this Node and its parent. Optionally
  /// provide any children of this node.
  SurfaceNode(
      {@required this.surface,
      this.relationToParent = const SurfaceRelation(),
      List<SurfaceNode> childNodes}) {
    if (childNodes != null && childNodes.isNotEmpty) {
      for (SurfaceNode childNode in childNodes) {
        add(childNode: childNode);
      }
    }
  }

  /// The surface represented by this [Node] in the [Tree]
  final Surface surface;

  /// The children of this node
  final List<SurfaceNode> _childNodes = <SurfaceNode>[];

  /// The parent of this node. This is a node in a Tree, there can only be one
  /// parent
  SurfaceNode _parentNode;

  /// The relationship this node has with its parent
  SurfaceRelation relationToParent;

  /// Direct ancestor of this
  SurfaceNode get parentNode => _parentNode;

  /// Get the children of this node
  Iterable<SurfaceNode> get childNodes => _childNodes.toList(growable: false);

  /// Direct descendents of parent, except this
  Iterable<SurfaceNode> get siblings => (_parentNode == null)
      ? new Iterable<SurfaceNode>.empty()
      : _parentNode.childNodes.where((SurfaceNode node) => node != this);

  /// Direct ancestors of this, starting at parent to root
  Iterable<SurfaceNode> get ancestors {
    List<SurfaceNode> ancestors = <SurfaceNode>[];
    SurfaceNode ancestor = _parentNode;
    while (ancestor != null) {
      ancestors.add(ancestor);
      ancestor = ancestor._parentNode;
    }
    return ancestors;
  }

  @override
  Iterator<SurfaceNode> get iterator {
    return flatten().iterator;
  }

  /// Breadth first flattening of SurfaceNode
  Iterable<SurfaceNode> flatten() {
    List<SurfaceNode> nodes = <SurfaceNode>[this];
    for (int i = 0; i < nodes.length; i++) {
      SurfaceNode node = nodes[i];
      nodes.addAll(node._childNodes);
    }
    return nodes;
  }

  /// Detach a child node, setting its parent to null
  void detach({SurfaceNode childNode}) {
    if (_childNodes.contains(childNode)) {
      // remove the parent from the child
      childNode._parentNode = null;
      // remove the child from the list of parent's children
      _childNodes.remove(childNode);
    }
  }

  /// Add a childNode to this SurfaceNode
  void add({@required SurfaceNode childNode}) {
    if (childNode == null) {
      return;
    }
    _childNodes.add(childNode);
    childNode._parentNode = this;
  }

  /// Reduces a SurfaceNode to some other object using passed in function.
  V reduceSurfaceNode<V>(V f(Surface surface, Iterable<V> children)) => f(
      surface,
      childNodes.map((SurfaceNode child) => child.reduceSurfaceNode(f)));

  @override
  String toString() {
    String edgeLabel = relationToParent?.arrangement?.toString() ?? '';
    String edgeArrow = '$edgeLabel->'.padLeft(6, '-');
    String parent = parentNode.isEmpty
        ? '${parentNode?.surface?.surfaceId} $edgeArrow'
        : '';
    return '$parent SurfaceNode[ '
        '\n\tsurface: ${surface.surfaceId}'
        '\n\tchildren: ${childNodes.map((f) => f?.surface?.surfaceId).toList()})'
        '\n\t]';
  }
}
