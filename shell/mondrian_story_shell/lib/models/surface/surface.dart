// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import '../tree.dart';
import 'surface_graph.dart';
import 'surface_properties.dart';
import 'surface_relation_util.dart';

/// The parentId that means no parent
const String kNoParent = '';

/// Details of a surface child view
class Surface extends Model {
  /// Public constructor
  Surface(this._graph, this.node, this.properties, this.relation,
      this.compositionPattern);

  Surface.fromJson(Map<String, dynamic> json)
      : node = new Tree<String>(value: json['id']),
        _graph = new SurfaceGraph(),
        compositionPattern = json['compositionPattern'],
        properties = new SurfaceProperties(),
        relation = SurfaceRelationUtil
            .decode(json['surfaceRelation'].cast<String, String>());

  final SurfaceGraph _graph;
  final Tree<String> node;

  /// Connection to underlying view
  ChildViewConnection connection;

  /// The properties of this surface
  final SurfaceProperties properties;

  /// The relationship this node has with its parent
  final SurfaceRelation relation;

  /// The pattern with which to compose this node with its parent
  final String compositionPattern;

  /// Whether or not this surface is currently dismissed
  bool get dismissed => _graph.isDismissed(node.value);

  /// Return the min width of this Surface
  double minWidth({double min = 0.0}) => math.max(0.0, min);

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
  Surface get parent => _surface(node.parent);

  /// The parentId of this node
  String get parentId => node.parent.value;

  /// The root surface
  Surface get root {
    List<Tree<String>> nodeAncestors = node.ancestors;
    return _surface(nodeAncestors.length > 1
        ? nodeAncestors[nodeAncestors.length - 2]
        : node);
  }

  /// The children of this node
  Iterable<Surface> get children => _surfaces(node.children);

  /// The siblings of this node
  Iterable<Surface> get siblings => _surfaces(node.siblings);

  /// The ancestors of this node
  Iterable<Surface> get ancestors => _surfaces(node.ancestors);

  /// This node and its descendents flattened into an Iterable
  Iterable<Surface> get flattened => _surfaces(node);

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
    Tree<Surface> root = new Tree<Surface>(value: _surface(node));
    while (root.ancestors.isNotEmpty &&
        root.value.relation.dependency == SurfaceDependency.dependent) {
      root = root.ancestors.first;
    }
    return _spanningTree(null, root.value,
        (Surface s) => s.relation.dependency == SurfaceDependency.dependent);
  }

  // TODO(jphsiao) SY-497: move spanning treee logic to make it testable.

  /// Spans the full tree of all copresenting surfaces starting with this
  Tree<Surface> get copresentSpanningTree => _spanningTree(
      null,
      _surface(node), // default to co-present if no opinion presented
      (Surface s) =>
          s.relation.arrangement == SurfaceArrangement.copresent ||
          s.relation.arrangement == SurfaceArrangement.none);

  Tree<Surface> _spanningTree(
      Surface previous, Surface current, bool condition(Surface s)) {
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
    Tree<Surface> root = new Tree<Surface>(value: _surface(node));
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
    Tree<String> containerNode = node.root.find(containerId);
    log.info('found: $node');
    Tree<Surface> root = new Tree<Surface>(value: _surface(containerNode));
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
  bool dismiss() => _graph.dismissSurface(node.value);

  /// Returns true if this surface can be dismissed
  bool canDismiss() => _graph.canDismissSurface(node.value);

  /// Remove this node from graph
  /// Returns true if this was removed
  bool remove() {
    // Only allow non-root surfaces to be removed
    if (node.parent?.value != null) {
      _graph.removeSurface(node.value);
      return true;
    }
    return false;
  }

  // Get the surface for this node
  Surface _surface(Tree<String> node) =>
      (node == null || node.value == null) ? null : _graph.getNode(node.value);

  Iterable<Surface> _surfaces(Iterable<Tree<String>> nodes) => nodes
      .where((Tree<String> node) => node != null && node.value != null)
      .map(_surface);

  @override
  String toString() {
    String edgeLabel = relation?.arrangement?.toString() ?? '';
    String edgeArrow = '$edgeLabel->'.padLeft(6, '-');
    String disconnected = connection == null ? '[DISCONNECTED]' : '';
    return '${edgeArrow}Surface ${node.value} $disconnected';
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
        _spanningTree(null, _surface(node), (Surface s) => true);

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

  List<String> _children() {
    List<String> ids = [];
    for (Tree<String> child in node.children) {
      ids.add(child.value);
    }
    return ids;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': node.value,
      'parentId': parentId,
      'surfaceRelation': SurfaceRelationUtil.toMap(relation),
      'compositionPattern': compositionPattern,
      'isDismissed': dismissed ? 'true' : 'false',
      'children': _children(),
    };
  }
}

/// Defines a Container root in the [Surface Graph], holds the layout description
class SurfaceContainer extends Surface {
  SurfaceContainer(
      SurfaceGraph graph,
      Tree<String> node,
      SurfaceProperties properties,
      SurfaceRelation relation,
      String compositionPattern,
      this._layouts)
      : super(graph, node, properties, relation, compositionPattern) {
    super.connection = null;
  }

  @override
  set connection(ChildViewConnection value) {
    log.warning('Cannot set a child view connection on a Container');
  }

  /// returns the layouts for this container;
  List<ContainerLayout> get layouts => _layouts;

  List<ContainerLayout> _layouts;
}
