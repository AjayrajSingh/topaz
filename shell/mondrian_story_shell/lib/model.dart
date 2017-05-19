// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.story/surface.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/model.dart';

import 'surface_details.dart';
import 'tree.dart';

void _log(String msg) {
  print('[MondrianFlutter] SurfaceGraph $msg');
}

/// The parentId that means no parent
const String kNoParent = '0';

typedef bool _SurfaceSpanningTreeCondition(Surface s);

/// Details of a surface child view
class Surface extends Model {
  Surface._internal(this._graph, this._node, this.properties, this.relation);

  final SurfaceGraph _graph;
  final Tree<String> _node;

  /// Connection to underlying view
  ChildViewConnection _connection;

  /// The ChildViewConnection that can be used to create ChildViews
  ChildViewConnection get connection => _connection;

  /// The properties of this surface
  final SurfaceProperties properties;

  /// The relationship this node has with its parent
  final SurfaceRelation relation;

  /// The parent of this node
  Surface get parent => _surface(_node.parent);

  /// The children of this node
  Iterable<Surface> get children => _surfaces(_node.children);

  /// The siblings of this node
  Iterable<Surface> get siblings => _surfaces(_node.siblings);

  /// The ancestors of this node
  Iterable<Surface> get ancestors => _surfaces(_node.ancestors);

  /// Spans the full tree of all copresenting surfaces starting with this
  Tree<Surface> get copresentSpanningTree => _spanningTree(
      null,
      _surface(_node),
      (Surface s) => s.relation.arrangement == SurfaceArrangement.copresent);

  Tree<Surface> _spanningTree(Surface previous, Surface current,
      _SurfaceSpanningTreeCondition condition) {
    Tree<Surface> tree = new Tree<Surface>(value: current);
    if (current.parent != previous &&
        current.parent != null &&
        condition(current)) {
      tree.add(_spanningTree(current, current.parent, condition));
    }
    for (Surface child in current.children) {
      if (child != previous && condition(child)) {
        tree.add(_spanningTree(current, child, condition));
      }
    }
    return tree;
  }

  /// Remove this node from graph
  /// Returns true if this was removed
  bool remove() {
    // Only allow non-root surfaces to be removed
    if (_node.parent?.value != null) {
      _graph.removeSurface(_node.value);
      return true;
    }
    return false;
  }

  // Get the surface for this node
  Surface _surface(Tree<String> node) => (node == null || node.value == null)
      ? null
      : _graph._surfaces[node.value];

  Iterable<Surface> _surfaces(Iterable<Tree<String>> nodes) => nodes
      .where((Tree<String> node) => (node != null && node.value != null))
      .map((Tree<String> node) => _surface(node));

  @override
  String toString() {
    String edgeLabel = relation?.toString() ?? '';
    String edgeArrow = '$edgeLabel->'.padLeft(6, '-');
    String disconnected = _connection == null ? '[DISCONNECTED]' : '';
    return '${edgeArrow}Surface${_node.value} $disconnected';
  }
}

/// Data structure to manage the relationships and relative focus of surfaces
class SurfaceGraph extends Model {
  /// Cache of surfaces
  final Map<String, Surface> _surfaces = new Map<String, Surface>();

  /// Surface relationship tree
  final Tree<String> _tree = new Tree<String>(value: null);

  /// The stack of previous focusedSurfaces, most focused at end
  final List<String> _focusedSurfaces = <String>[];

  /// The currently most focused [Surface]
  Surface get focused =>
      _focusedSurfaces.isEmpty ? null : _surfaces[_focusedSurfaces.last];

  /// The history of focused [Surface]s
  Iterable<Surface> get focusStack =>
      _focusedSurfaces.map((String id) => _surfaces[id]);

  /// Add [Surface] to graph
  void addSurface(
    String id,
    SurfaceProperties properties,
    String parentId,
    SurfaceRelation relation,
  ) {
    assert(!_surfaces.keys.contains(id));
    Tree<String> node = new Tree<String>(value: id);
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.search(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    _surfaces[id] = new Surface._internal(this, node, properties, relation);
    notifyListeners();
  }

  /// Removes [Surface] from graph
  void removeSurface(String id) {
    // TODO(alangardner): Remap edges to transitive nodes appropriately
    if (_surfaces.keys.contains(id)) {
      Tree<String> node = _tree.search(id);
      Tree<String> parent = node.parent;
      node.detach();
      for (Tree<String> child in node.children) {
        parent.add(child);
      }
      _focusedSurfaces.remove(id);
      _surfaces.remove(id);
    }
  }

  /// Push a new focus onto the focus stack, replacing the current focus
  void focusSurface(String id) {
    assert(_surfaces.keys.contains(id));
    if (_focusedSurfaces.isEmpty || _focusedSurfaces.last != id) {
      _focusedSurfaces.remove(id);
      _focusedSurfaces.add(id);
      notifyListeners();
    }
  }

  /// Used to update a [Surface] with a live ChildViewConnection
  void connectView(String id, InterfaceHandle<ViewOwner> viewOwner) {
    final Surface surface = _surfaces[id];
    if (surface != null) {
      _log('connectView $surface');
      surface._connection = new ChildViewConnection(
        viewOwner,
        onAvailable: (ChildViewConnection connection) {
          surface.notifyListeners();
        },
        onUnavailable: (ChildViewConnection connection) {
          surface._connection = null;
          removeSurface(id);
          notifyListeners();
          // Also any existing listener
          surface.notifyListeners();
        },
      );
      surface.notifyListeners();
    }
  }

  /// Returns the amount of [Surface]s in the graph
  int get size => _surfaces.length;

  @override
  String toString() =>
      'Tree:\n' +
      _tree.children.map((Tree<String> child) => _toString(child)).join('\n');

  String _toString(Tree<String> node, {String prefix: ''}) {
    String nodeString = '$prefix${_surfaces[node.value]}';
    if (node.children.isNotEmpty) {
      nodeString += '\n' +
          node.children
              .map((Tree<String> node) => _toString(node, prefix: '$prefix  '))
              .join('\n');
    }
    return '$nodeString';
  }
}
