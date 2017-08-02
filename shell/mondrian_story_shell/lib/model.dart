// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:apps.modular.services.surface/surface.fidl.dart';
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
const String kNoParent = '';

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

  /// Whether or not this surface is currently dismissed
  bool get dismissed => _graph.isDismissed(_node.value);

  /// Return the min width of this Surface
  double minWidth({double min: 0.0}) =>
      max(properties?.constraints?.minWidth ?? 0.0, min);

  /// Return the absolute emphasis given some root displayed Surface
  double absoluteEmphasis(Surface relative) {
    assert(root == relative.root);
    Iterable<Surface> relativeAncestors = relative.ancestors;
    Surface ancestor = this;
    double emphasis = 1.0;
    while (ancestor != relative && !relativeAncestors.contains(ancestor)) {
      emphasis *= ancestor.relation.emphasis;
      ancestor = ancestor.parent;
    }
    Surface aRelative = relative;
    while (ancestor != aRelative) {
      emphasis /= aRelative.relation.emphasis;
      aRelative = aRelative.parent;
    }
    return emphasis;
  }

  /// The parent of this node
  Surface get parent => _surface(_node.parent);

  /// The root surface
  Surface get root {
    List<Tree<String>> nodeAncestors = _node.ancestors;
    return _surface(nodeAncestors.length > 1
        ? nodeAncestors[nodeAncestors.length - 2]
        : _node);
  }

  /// The children of this node
  Iterable<Surface> get children => _surfaces(_node.children);

  /// The siblings of this node
  Iterable<Surface> get siblings => _surfaces(_node.siblings);

  /// The ancestors of this node
  Iterable<Surface> get ancestors => _surfaces(_node.ancestors);

  /// This node and its descendents flattened into an Iterable
  Iterable<Surface> get flattened => _surfaces(_node);

  /// Returns a Tree for this surface
  Tree<Surface> get tree {
    Tree<Surface> t = new Tree<Surface>(value: this);
    for (Surface child in children) {
      t.add(child.tree);
    }
    return t;
  }

  /// Gets the dependent spanning tree the current widget is part of
  Tree<Surface> get dependentSpanningTree {
    Tree<Surface> root = new Tree<Surface>(value: _surface(_node));
    while (root.ancestors.isNotEmpty &&
        root.value.relation.dependency == SurfaceDependency.dependent) {
      root = root.ancestors.first;
    }
    return _spanningTree(null, root.value,
        (Surface s) => s.relation.dependency == SurfaceDependency.dependent);
  }

  /// Spans the full tree of all copresenting surfaces starting with this
  Tree<Surface> get copresentSpanningTree => _spanningTree(
      null,
      _surface(_node), // default to co-present if no opinion presented
      (Surface s) =>
          s.relation.arrangement == SurfaceArrangement.copresent ||
          s.relation.arrangement == SurfaceArrangement.none);

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

  /// Dismiss this node hiding it from layouts
  bool dismiss() => _graph.dismissSurface(_node.value);

  /// Returns true if this surface can be dismissed
  bool canDismiss() => _graph.canDismissSurface(_node.value);

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
    String edgeLabel = relation?.arrangement?.toString() ?? '';
    String edgeArrow = '$edgeLabel->'.padLeft(6, '-');
    String disconnected = _connection == null ? '[DISCONNECTED]' : '';
    return '${edgeArrow}Surface${_node.value} $disconnected';
  }

  List<Tree<Surface>> _endsOfChain({Tree<Surface> current}) {
    List<Tree<Surface>> ends = <Tree<Surface>>[];
    current.children.forEach((Tree<Surface> s) {
      if (s.value.relation.dependency != SurfaceDependency.dependent) {
        ends.add(s);
      } else {
        ends.addAll(_endsOfChain(current: s));
      }
    });
    return ends;
  }

  /// Returns the List (forest) of DependentSpanningTrees in the current graph
  Forest<Surface> getDependentSpanningTrees() {
    List<Tree<Surface>> queue = <Tree<Surface>>[];
    Forest<Surface> forest = new Forest<Surface>();

    Tree<Surface> tree =
        _spanningTree(null, _surface(_node), (Surface s) => true);

    queue.add(tree);
    while (queue.isNotEmpty) {
      Tree<Surface> t = queue.removeAt(0);
      List<Tree<Surface>> ends = _endsOfChain(current: t);
      queue.addAll(ends);
      ends.forEach((Tree<Surface> s) {
        t.find(s.value).detach();
      });
      forest.add(t);
    }
    return forest;
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

  /// The stack of previous focusedSurfaces, most focused at end
  final Set<String> _dismissedSurfaces = new Set<String>();

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
    Tree<String> node = _tree.find(id) ?? new Tree<String>(value: id);
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.find(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    Surface oldSurface = _surfaces[id];
    _surfaces[id] = new Surface._internal(this, node, properties, relation);
    oldSurface?.notifyListeners();
    notifyListeners();
  }

  /// Removes [Surface] from graph
  void removeSurface(String id) {
    // TODO(alangardner): Remap edges to transitive nodes appropriately
    if (_surfaces.keys.contains(id)) {
      Tree<String> node = _tree.find(id);
      Tree<String> parent = node.parent;
      node.detach();
      for (Tree<String> child in node.children) {
        parent.add(child);
      }
      _focusedSurfaces.remove(id);
      _dismissedSurfaces.remove(id);
      _surfaces.remove(id);
      notifyListeners();
    }
  }

  /// Move the surface up in the focus stack, undismissing it if needed.
  ///
  /// If relativeId is null, the surface is re-inserted  at the top of the stack
  /// If relativeId is provided, the surface is re-inserted at the higher of
  /// above the relative surface or any of its direct children, or its original
  /// position.
  void focusSurface(String id, String relativeId) {
    _log('focusSurface($id)');
    assert(_surfaces.containsKey(id));
    _dismissedSurfaces.remove(id);
    if (relativeId == null || relativeId == kNoParent) {
      _focusedSurfaces.remove(id);
      _focusedSurfaces.add(id);
    } else {
      assert(_surfaces.containsKey(relativeId));
      int currentIndex = _focusedSurfaces.indexOf(id);
      _focusedSurfaces.remove(id);
      final Tree<String> relative = _tree.find(relativeId);
      int relativeIndex = _focusedSurfaces.indexOf(relative.value);
      // Use the highest index of relative or its children
      for (Tree<String> childNode in relative.children) {
        String childId = childNode.value;
        relativeIndex = max(relativeIndex, _focusedSurfaces.indexOf(childId));
      }
      // If none of those are focused, find the closest ancestor that is focused
      Tree<String> ancestor = relative.parent;
      while (relativeIndex < 0 && ancestor.value != null) {
        relativeIndex = _focusedSurfaces.indexOf(ancestor.value);
        ancestor = ancestor.parent;
      }
      // Insert to the highest of one past relative index, or the original index
      int index = max(relativeIndex < 0 ? -1 : relativeIndex + 1, currentIndex);
      if (index >= 0) {
        _focusedSurfaces.insert(index, id);
      }
    }
    notifyListeners();
  }

  /// Returns the list of surfaces that would be dismissed if this surface
  /// were dismissed - e.g. as a result of dependency - including this surface
  List<String> dismissedSet(String id) {
    Surface dismissed = _surfaces[id];
    List<Surface> ancestors = dismissed.ancestors.toList();
    List<Surface> dependentTree = dismissed.dependentSpanningTree
        .map((Tree<Surface> t) => t.value)
        .toList();
    // TODO(djmurphy) - when codependent comes in this needs to change
    // this only removes down the tree, codependents would remove their
    // ancestors
    dependentTree.removeWhere((Surface s) => ancestors.contains(s));
    List<String> depIds =
        dependentTree.map((Surface s) => s._node.value).toList();
    return depIds;
  }

  /// Check if given surface can be dismissed
  bool canDismissSurface(String id) {
    List<String> wouldDismiss = dismissedSet(id);
    return _focusedSurfaces
        .where((String fid) => !wouldDismiss.contains(fid))
        .isNotEmpty;
  }

  /// When called surface is no longer displayed
  bool dismissSurface(String id) {
    if (!canDismissSurface(id)) {
      return false;
    }
    List<String> depIds = dismissedSet(id);
    _focusedSurfaces.removeWhere((String fid) => depIds.contains(fid));
    _dismissedSurfaces.addAll(depIds);
    notifyListeners();
    return true;
  }

  /// True if surface has been dismissed and not subsequently focused
  bool isDismissed(String id) => _dismissedSurfaces.contains(id);

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
          if (_surfaces.containsValue(surface)) {
            removeSurface(id);
            notifyListeners();
          }
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
