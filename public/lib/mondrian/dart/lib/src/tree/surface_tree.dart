// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';
import '../surface/surface.dart';
import '../surface/surface_relation.dart';
import './surface_node.dart';

/// A SurfaceTree of SurfaceNodes
class SurfaceTree extends Iterable<Surface> {
  /// Construct [SurfaceTree]
  SurfaceTree() {
    setupLogger(name: 'libMondrian', level: Level.FINE);
  }

  /// The root of the SurfaceTree. SurfaceNodes added to the Tree without
  /// specifying parents are added to the root.
  final SurfaceNode kRoot = SurfaceNode(surface: Surface(surfaceId: '_kRoot_'));

  /// Map from SurfaceIds to SurfaceNodes, for all the SurfaceNodes in the Forest
  final Map<String, SurfaceNode> _nodeMap = {};

  /// Add a SurfaceNode node to the SurfaceTree. The node will be added to a
  /// parent matching optional parentId, or to the root.
  void _addNode({
    @required SurfaceNode node,
    String parentId,
  }) {
    // If the Surface is already in the Tree, return;
    if (_nodeMap.containsKey(node.surface.surfaceId)) {
      log
        ..warning(
            'Surface with id "${node.surface.surfaceId}" already in tree.')
        ..warning('Use update() to modify existing Surfaces.'
            'Surface will not be not re-added.');
      return;
    }
    // If an invalid parent was specified throw an error
    if (parentId != null && !_nodeMap.containsKey(parentId)) {
      throw (ArgumentError.value(
          parentId, 'parentId', 'not found in SurfaceTree'));
    }
    // If a valid parent was specified, add to the parent
    if (parentId != null) {
      // add node as child of parent if we can find the parent
      _nodeMap[parentId].add(childNode: node);
      _nodeMap[node.surface.surfaceId] = node;
      // else add to the root
    } else {
      kRoot.add(childNode: node);
      _nodeMap[node.surface.surfaceId] = node;
    }
  }

  /// Add a Surface to this Tree, optionally attach this Surface to the given
  /// parent.
  void add({
    @required Surface surface,
    String parentId,
    SurfaceRelation relationToParent,
  }) {
    SurfaceNode node = SurfaceNode(surface: surface);
    if (relationToParent != null) {
      node.relationToParent = relationToParent;
    }
    _addNode(node: node, parentId: parentId);
  }

  /// Destructively removes the node from the SurfaceTree, and reparents any
  /// children to the root
  void remove({@required String surfaceId}) {
    if (_nodeMap.containsKey(surfaceId)) {
      SurfaceNode node = _nodeMap[surfaceId];
      _nodeMap.remove(surfaceId);
      // detach the node from its parent
      node.parentNode?.detach(childNode: node);
      // reparent any children on the root of the tree
      for (SurfaceNode child in node.childNodes) {
        // make the children orphans
        node.detach(childNode: child);
        // remove them from the graph
        _nodeMap.remove(child.surface.surfaceId);
        // add them to the root
        _addNode(node: child);
      }
      // remove the node from the nodeMap
    }
  }

  /// Update the [parentId] and the [relation] to the parent of a [Surface]
  /// The Surface must exist in the [Tree]
  /// NOTE! If the parentId is not specified, the child will be orphaned and
  /// reparented on the root!
  void update({
    @required Surface surface,
    String parentId,
    SurfaceRelation relation,
  }) {
    if (parentId == null && relation != null) {
      throw (ArgumentError.value(
          parentId,
          'parentId',
          'Relationship provided, but parent not specified. Relationships are'
          'between parents and children'));
    }
    SurfaceNode oldNode = _nodeMap[surface.surfaceId];
    SurfaceNode newNode =
        SurfaceNode(surface: surface, relationToParent: relation);

    /// If the node had a parent, detach and reparent the updated node
    if (parentId != null && _nodeMap[parentId] != null) {
      _nodeMap[parentId]
        ..detach(childNode: oldNode)
        ..add(childNode: newNode);
    }
    _nodeMap[surface.surfaceId] = newNode;
  }

  @override
  Iterator<Surface> get iterator {
    return flatten().iterator;
  }

  /// Breadth first flattening of SurfaceNode
  Iterable<Surface> flatten() {
    return kRoot.flatten().map((f) => f.surface).toList()
      ..remove(kRoot.surface); // The root is an implementation detail
  }

  /// Find Surface by surfaceId
  SurfaceNode findNode({String surfaceId}) => _nodeMap[surfaceId];

  /// Reduces a Forest to a list of objects.
  Iterable<V> reduceSurfaceTree<V>(
          V f(Surface surface, Iterable<V> children)) =>
      kRoot.map((SurfaceNode t) => t.reduceSurfaceNode(f));

  /// Get a flattened iterable of all of the values in the forest
  Iterable get values => flatten();

  @override
  String toString() => 'SurfaceTree($kRoot)';

  /// Creates a spanning tree with a given condition
  SurfaceTree spanningTree(
      {@required String startNodeId, @required bool condition(SurfaceNode s)}) {
    SurfaceNode startNode;
    if (_nodeMap.containsKey(startNodeId)) {
      startNode = _nodeMap[startNodeId];
    } else {
      log.warning('node $startNodeId not found in tree, '
          'returning empty spanningTree');
      return new SurfaceTree();
    }
    // find the topmost point of the connected tree where the relationship holds
    // (excluding the kRoot, which is not a valid Surface)
    while (startNode?.parentNode != null &&
        condition(startNode) &&
        // the root not a valid surface
        startNode?.parentNode != kRoot) {
      startNode = startNode.parentNode;
    }
    // then return all the descendents who satisfy condition
    SurfaceTree spanTree = new SurfaceTree()..add(surface: startNode.surface);
    __copyTreeWithConditional(
        current: startNode, tree: spanTree, condition: condition);
    return spanTree;
  }

  // recursively search down surface nodes, adding children that match condition
  // to tree;
  void __copyTreeWithConditional(
      {SurfaceNode current, SurfaceTree tree, bool condition(SurfaceNode s)}) {
    for (SurfaceNode child in current.childNodes) {
      if (condition(child)) {
        tree.add(surface: child.surface, parentId: current.surface.surfaceId);
        __copyTreeWithConditional(
            current: child, tree: tree, condition: condition);
      }
    }
  }
}
