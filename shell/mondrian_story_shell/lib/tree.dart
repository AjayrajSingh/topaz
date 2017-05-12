// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Simple mutable tree data structure
class Tree<T> extends Iterable<Tree<T>> {
  /// Construct [Tree]
  Tree({@required this.value, Iterable<Tree<T>> children}) {
    children?.forEach((Tree<T> child) => add(child));
  }

  /// The nodes value
  final T value;

  /// Direct descendents of this
  Iterable<Tree<T>> get children => _children.toList(growable: false);
  final List<Tree<T>> _children = <Tree<T>>[];

  /// Direct descendents of parent, except this
  Iterable<Tree<T>> get siblings => (_parent == null)
      ? const Iterable<Tree<T>>.empty()
      : _parent.children.where((Tree<T> node) => node != this);

  /// Direct ancestor of this
  Tree<T> get parent => _parent;
  Tree<T> _parent;

  /// The root of the tree this node is a part of
  Tree<T> get root {
    Tree<T> node = this;
    while (node._parent != null) {
      node = _parent;
    }
    return node;
  }

  @override
  Iterator<Tree<T>> get iterator {
    List<Tree<T>> nodes = <Tree<T>>[];
    _traverse(nodes);
    return nodes.iterator;
  }

  void _traverse(List<Tree<T>> nodes) {
    nodes.add(this);
    for (Tree<T> child in _children) {
      child._traverse(nodes);
    }
  }

  /// Detach this tree from its parents tree
  void detach() {
    _parent._children.remove(this);
    _parent = null;
  }

  /// Add a child to this tree
  void add(Tree<T> child) {
    assert(child != null);
    _children.add(child);
    child._parent = this;
  }

  /// Find the single Tree node with the following value
  ///
  /// Note: Search order not specified (so make sure values are unique)
  Tree<T> search(T value) =>
      this.firstWhere((Tree<T> node) => node.value == value);
}
