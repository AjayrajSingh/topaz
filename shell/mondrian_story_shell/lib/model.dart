// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:fidl/fidl.dart';
import 'package:fidl_modular/fidl.dart';
import 'package:fidl_views_v1_token/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import 'surface_details.dart';
import 'tree.dart';

/// The parentId that means no parent
const String kNoParent = '';

typedef bool _SurfaceSpanningTreeCondition(Surface s);

/// Details of a surface child view
class Surface extends Model {
  /// Public constructor
  Surface(this._graph, this._node, this.properties, this.relation,
      this.compositionPattern);

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

  /// The pattern with which to compose this node with its parent
  final String compositionPattern;

  /// Whether or not this surface is currently dismissed
  bool get dismissed => _graph.isDismissed(_node.value);

  /// Return the min width of this Surface
  double minWidth({double min: 0.0}) =>
      math.max(properties?.constraints?.minWidth ?? 0.0, min);

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

  /// The parentId of this node
  String get parentId => _node.parent.value;

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
        tree.add(
          _spanningTree(current, child, condition),
        );
      }
    }
    return tree;
  }

  /// Gets the pattern spanning tree the current widget is part of
  Tree<Surface> patternSpanningTree(String pattern) {
    Tree<Surface> root = new Tree<Surface>(value: _surface(_node));
    while (
        root.ancestors.isNotEmpty && root.value.compositionPattern == pattern) {
      root = root.ancestors.first;
    }
    return _spanningTree(
        null, root.value, (Surface s) => s.compositionPattern == pattern);
  }

  /// Gets the spanning tree of Surfaces participating in the Container
  /// identified by containerId
  Tree<Surface> containerSpanningTree(String containerId) {
    log.info('looking for container: $containerId');
    Tree<String> node = _node.root.find(containerId);
    log.info('found: $node');
    Tree<Surface> root = new Tree<Surface>(value: _surface(node));
    log.info('root: $root');
    if (root.value is SurfaceContainer) {
      return _spanningTree(
        null,
        root.value,
        (Surface s) =>
            // TODO: (djmurphy) this will fail nested containers
            s.properties.containerMembership != null &&
            s.properties.containerMembership.contains(containerId),
      );
    } else {
      return root;
    }
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
      .map(_surface);

  @override
  String toString() {
    String edgeLabel = relation?.arrangement?.toString() ?? '';
    String edgeArrow = '$edgeLabel->'.padLeft(6, '-');
    String disconnected = _connection == null ? '[DISCONNECTED]' : '';
    return '${edgeArrow}Surface${_node.value} $disconnected';
  }

  List<Tree<Surface>> _endsOfChain({Tree<Surface> current}) {
    List<Tree<Surface>> ends = <Tree<Surface>>[];
    for (Tree<Surface> s in current.children) {
      if (s.value.relation.dependency != SurfaceDependency.dependent) {
        ends.add(s);
      } else {
        ends.addAll(_endsOfChain(current: s));
      }
    }
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
      for (Tree<Surface> s in ends) {
        t.find(s.value).detach();
      }
      forest.add(t);
    }
    return forest;
  }
}

/// Defines a Container root in the [Surface Graph], holds the layout description
class SurfaceContainer extends Surface {
  SurfaceContainer._internal(
      SurfaceGraph graph,
      Tree<String> node,
      SurfaceProperties properties,
      SurfaceRelation relation,
      String compositionPattern,
      this._layouts)
      : super(graph, node, properties, relation, compositionPattern) {
    super._connection = null;
  }

  @override
  set _connection(ChildViewConnection value) {
    log.warning('Cannot set a child view connection on a Container');
  }

  /// returns the layouts for this container;
  List<ContainerLayout> get layouts => _layouts;

  List<ContainerLayout> _layouts;
}

/// Data structure to manage the relationships and relative focus of surfaces
class SurfaceGraph extends Model {
  /// Cache of surfaces
  final Map<String, Surface> _surfaces = <String, Surface>{};

  /// Surface relationship tree
  final Tree<String> _tree = new Tree<String>(value: null);

  /// The stack of previous focusedSurfaces, most focused at end
  final List<String> _focusedSurfaces = <String>[];

  /// The stack of previous focusedSurfaces, most focused at end
  final Set<String> _dismissedSurfaces = new Set<String>();

  /// The last focused surface.
  Surface _lastFocusedSurface;

  /// The currently most focused [Surface]
  Surface get focused =>
      _focusedSurfaces.isEmpty ? null : _surfaces[_focusedSurfaces.last];

  /// The history of focused [Surface]s
  Iterable<Surface> get focusStack => _focusedSurfaces
      .where(_surfaces.containsKey)
      .map((String id) => _surfaces[id]);

  /// Add [Surface] to graph
  void addSurface(
    String id,
    SurfaceProperties properties,
    String parentId,
    SurfaceRelation relation,
    String pattern,
  ) {
    Tree<String> node = _tree.find(id) ?? new Tree<String>(value: id);
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.find(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    Surface oldSurface = _surfaces[id];
    _surfaces[id] = new Surface(this, node, properties, relation, pattern);
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
      node.children.forEach(parent.add);
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
    if (!_surfaces.containsKey(id)) {
      log.warning('Invalid surface id "$id"');
      return;
    }
    int currentIndex = _focusedSurfaces.indexOf(id);
    _dismissedSurfaces.remove(id);
    _focusedSurfaces.remove(id);
    if (relativeId == null || relativeId == kNoParent) {
      _focusedSurfaces.add(id);
    } else {
      int relativeIndex = -1;
      final Tree<String> relative = _tree.find(relativeId);
      if (relative != null) {
        relativeIndex = _focusedSurfaces.indexOf(relative.value);
        // Use the highest index of relative or its children
        for (Tree<String> childNode in relative.children) {
          String childId = childNode.value;
          relativeIndex =
              math.max(relativeIndex, _focusedSurfaces.indexOf(childId));
        }
        // If none of those are focused, find the closest ancestor that is focused
        Tree<String> ancestor = relative.parent;
        while (relativeIndex < 0 && ancestor.value != null) {
          relativeIndex = _focusedSurfaces.indexOf(ancestor.value);
          ancestor = ancestor.parent;
        }
      }
      // Insert to the highest of one past relative index, or the original index
      int index =
          math.max(relativeIndex < 0 ? -1 : relativeIndex + 1, currentIndex);
      if (index >= 0) {
        _focusedSurfaces.insert(index, id);
      }
    }

    // Also request the input focus through the child view connection.
    _surfaces[id].connection.requestFocus();
    _lastFocusedSurface = _surfaces[id];

    notifyListeners();
  }

  /// Add a container root to the surface graph
  void addContainer(
    String id,
    SurfaceProperties properties,
    String parentId,
    SurfaceRelation relation,
    List<ContainerLayout> layouts,
  ) {
    // TODO (djurphy): collisions/pathing - partial fix if we
    // make the changes so container IDs are paths.
    log.info('addContainer: $id');
    Tree<String> node = _tree.find(id) ?? new Tree<String>(value: id);
    log.info('found or made node: $node');
    Tree<String> parent =
        (parentId == kNoParent) ? _tree : _tree.find(parentId);
    assert(parent != null);
    assert(relation != null);
    parent.add(node);
    Surface oldSurface = _surfaces[id];
    _surfaces[id] = new SurfaceContainer._internal(
        this, node, properties, relation, '' /*pattern*/, layouts);
    oldSurface?.notifyListeners();
    log.info('_surfaces[id]: ${_surfaces[id]}');
    notifyListeners();
  }

  /// Returns the list of surfaces that would be dismissed if this surface
  /// were dismissed - e.g. as a result of dependency - including this surface
  List<String> dismissedSet(String id) {
    Surface dismissed = _surfaces[id];
    List<Surface> ancestors = dismissed.ancestors.toList();
    List<Surface> dependentTree = dismissed.dependentSpanningTree
        .map((Tree<Surface> t) => t.value)
        .toList()
          // TODO(djmurphy) - when codependent comes in this needs to change
          // this only removes down the tree, codependents would remove their
          // ancestors
          ..removeWhere((Surface s) => ancestors.contains(s));
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
      log.fine('connectView $surface');
      surface
        .._connection = new ChildViewConnection(
          viewOwner,
          onAvailable: (ChildViewConnection connection) {
            trace('surface $id available');

            // If this surface is the last focused one, also request input focus
            if (_lastFocusedSurface == surface) {
              connection.requestFocus();
            }

            surface.notifyListeners();
          },
          onUnavailable: (ChildViewConnection connection) {
            trace('surface $id unavailable');
            surface._connection = null;
            if (_surfaces.containsValue(surface)) {
              removeSurface(id);
              notifyListeners();
            }
            // Also any existing listener
            surface.notifyListeners();
          },
        )
        ..notifyListeners();
    }
  }

  /// Returns the amount of [Surface]s in the graph
  int get size => _surfaces.length;

  @override
  String toString() => 'Tree:\n${_tree.children.map(_toString).join('\n')}';

  String _toString(Tree<String> node, {String prefix: ''}) {
    String nodeString = '$prefix${_surfaces[node.value]}';
    if (node.children.isNotEmpty) {
      nodeString =
          '$nodeString\n${node.children.map((Tree<String> node) => _toString(node, prefix: '$prefix  ')).join('\n')}';
    }
    return '$nodeString';
  }
}
