// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This makes the export method more readable.
// ignore_for_file: cascade_invocations

/// Utility to create and export simple directed graphs.
class Graph {
  final Map<String, Node> _nodes = <String, Node>{};
  final Map<Node, Set<Node>> _edges = <Node, Set<Node>>{};

  int _nextId = 0;
  Node _root;

  /// Returns or creates a node with the given [label].
  Node getNode(String label) =>
      _nodes.putIfAbsent(label, () => new Node._internal(label, _nextId++));

  /// Sets the graph's root node.
  set root(Node node) {
    if (!_nodes.containsValue(node)) {
      throw new Exception('Unknown node: $node');
    }
    _root = node;
  }

  /// Inserts a new edge.
  void addEdge({Node from, Node to}) =>
      _edges.putIfAbsent(from, () => new Set<Node>()).add(to);

  /// Removes and returns all singletons from the graph.
  List<Node> removeSingletons() {
    final List<Node> singletons = _nodes.values
        .where((Node node) =>
            !_edges.containsKey(node) &&
            _edges.values.every((Set<Node> nodes) => !nodes.contains(node)))
        .toList();
    for (Node node in singletons) {
      _nodes.remove(node.label);
    }
    return singletons;
  }

  /// Returns the nodes which do not have a parent.
  List<Node> get orphans => _nodes.values
      .where((Node node) =>
          node != _root &&
          _edges.values.every((Set<Node> nodes) => !nodes.contains(node)))
      .toList();

  /// Creates a string representation of this graph in the DOT format.
  void export(String name, StringSink out) {
    out.writeln('digraph $name {');
    for (Node node in _nodes.values) {
      out.writeln('${node.id} [label="${node.label}"];');
    }
    if (_root != null) {
      out.writeln('root=${_root.id};');
    }
    for (Node from in _edges.keys) {
      for (Node to in _edges[from]) {
        out.writeln('${from.id} -> ${to.id};');
      }
    }
    out.writeln('}');
  }
}

/// A node in the graph.
class Node {
  /// The node's id.
  final int id;

  /// The node's label.
  final String label;

  Node._internal(this.label, this.id);

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) => other is Node && other.id == id;

  @override
  int get hashCode => id;
}
