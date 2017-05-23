// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:meta/meta.dart';

/// Simple mutable tree data structure
class Tree<T> extends Iterable<Tree<T>> {
  /// Construct [Tree]
  Tree({@required this.value, Iterable<Tree<T>> children}) {
    children?.forEach((Tree<T> child) => add(child));
  }

  /// The nodes value
  final T value;

  /// The longest path of edges to a leaf
  int get height => _children.isEmpty
      ? 0
      : 1 + _children.fold(0, (int h, Tree<T> t) => max(h, t.height));

  /// Direct descendents of this
  Iterable<Tree<T>> get children => _children.toList(growable: false);
  final List<Tree<T>> _children = <Tree<T>>[];

  /// Direct descendents of parent, except this
  Iterable<Tree<T>> get siblings => (_parent == null)
      ? const Iterable<Tree<T>>.empty()
      : _parent.children.where((Tree<T> node) => node != this);

  /// Direct ancestors of this, starting at parent to root
  Iterable<Tree<T>> get ancestors {
    List<Tree<T>> ancestors = <Tree<T>>[];
    Tree<T> ancestor = this;
    while (ancestor._parent != null) {
      ancestor = ancestor._parent;
      ancestors.add(ancestor);
    }
    return ancestors;
  }

  /// Direct ancestor of this
  Tree<T> get parent => _parent;
  Tree<T> _parent;

  /// The root of the tree this node is a part of
  Tree<T> get root {
    Tree<T> node = this;
    while (node._parent != null) {
      node = node._parent;
    }
    return node;
  }

  @override
  Iterator<Tree<T>> get iterator {
    return flatten().iterator;
  }

  /// Breadth first flattening of tree
  Iterable<Tree<T>> flatten({
    int orderChildren(Tree<T> l, Tree<T> r),
  }) {
    List<Tree<T>> nodes = <Tree<T>>[this];
    for (int i = 0; i < nodes.length; i++) {
      Tree<T> node = nodes[i];
      if (orderChildren == null) {
        nodes.addAll(node._children);
      } else {
        nodes.addAll(node._children.toList()..sort(orderChildren));
      }
    }
    return nodes;
  }

  /// Detach this tree from its parents tree
  void detach() {
    if (parent != null) {
      _parent._children.remove(this);
      _parent = null;
    }
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
  Tree<T> find(T value) => this
      .firstWhere((Tree<T> node) => node.value == value, orElse: () => null);
}
