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
      ? new Iterable<Tree<T>>.empty()
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

  /// Generate a new tree with the same structure with transformed values
  Tree<V> mapTree<V>(V f(T value)) => new Tree<V>(
        value: f(value),
        children: _children.map((Tree<T> n) => n.mapTree(f)),
      );

  /// Get a flattened iterable of all of the values in the tree
  Iterable<T> get values => flatten().map((Tree<T> t) => t.value);
}

/// A collection of trees
class Forest<T> extends Iterable<Tree<T>> {
  /// Construct [Forest]
  Forest({Iterable<Tree<T>> roots}) {
    roots?.forEach((Tree<T> root) => add(root));
  }

  /// Root nodes of this forest
  Iterable<Tree<T>> get roots => _roots.toList(growable: false);
  final List<Tree<T>> _roots = <Tree<T>>[];

  /// The longest path of edges to a leaf
  int get height => _roots.isEmpty
      ? 0
      : _roots.fold(0, (int h, Tree<T> t) => max(h, t.height));

  /// Add a root node to this forest
  void add(Tree<T> node) {
    assert(node != null);
    node.detach();
    _roots.add(node);
  }

  /// Removes the node from the tree, and reparents children.
  ///
  /// Reparents its children to the nodes parent or as root nodes.
  void remove(Tree<T> node) {
    assert(node != null);
    if (this.contains(node)) {
      Tree<T> parent = node.parent;
      if (parent == null) {
        for (Tree<T> child in node.children) {
          add(child);
        }
        this._roots.remove(node);
      } else {
        node.detach();
        for (Tree<T> child in node.children) {
          parent.add(child);
        }
      }
    }
  }

  @override
  Iterator<Tree<T>> get iterator {
    return flatten().iterator;
  }

  /// Breadth first flattening of tree
  Iterable<Tree<T>> flatten({
    int orderChildren(Tree<T> l, Tree<T> r),
  }) {
    List<Tree<T>> roots = _roots.toList();
    if (orderChildren != null) {
      roots.sort(orderChildren);
    }
    List<Tree<T>> nodes = <Tree<T>>[];
    for (Tree<T> node in roots) {
      nodes.addAll(node.flatten(orderChildren: orderChildren));
    }
    return nodes;
  }

  /// Find the single Tree node with the following value
  ///
  /// Note: Search order not specified (so make sure values are unique)
  Tree<T> find(T value) => this
      .firstWhere((Tree<T> node) => node.value == value, orElse: () => null);

  /// Generate a new forest with the same structure with transformed values
  Forest<V> mapForest<V>(V f(T value)) => new Forest<V>(
        roots: _roots.map((Tree<T> n) => n.mapTree(f)),
      );

  /// Get a flattened iterable of all of the values in the forest
  Iterable<T> get values => flatten().map((Tree<T> t) => t.value);
}
