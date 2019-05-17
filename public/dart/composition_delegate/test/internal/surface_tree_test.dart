// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:composition_delegate/composition_delegate.dart';
import 'package:composition_delegate/src/internal/tree/_surface_node.dart';
import 'package:composition_delegate/src/internal/tree/_surface_tree.dart';
import 'package:test/test.dart';

void main() {
  SurfaceTree tree;
  Surface grandparent;
  Surface parent;
  Surface child;
  Surface depParent;
  Surface depChild;
  Surface independent;
  SurfaceTree depTree;
  bool condition(SurfaceNode s) =>
      s.relationToParent?.dependency == SurfaceDependency.dependent;

  setUp(() {
    /// Set up a regular tree
    tree = SurfaceTree();
    grandparent = Surface(surfaceId: 'grandparent');
    parent = Surface(surfaceId: 'parent');
    child = Surface(surfaceId: 'child');

    /// Set up a tree with relationships
    depParent = Surface(
      surfaceId: parent.surfaceId,
    );
    depChild = Surface(
      surfaceId: child.surfaceId,
    );
    independent = Surface(surfaceId: 'independent');
    // make tree with dependency relationships:
    // gp <-dep- parent <-dep- child <-indep- independent
    depTree = SurfaceTree()
      ..add(surface: grandparent)
      ..add(
        surface: depParent,
        parentId: grandparent.surfaceId,
        relationToParent:
            SurfaceRelation(dependency: SurfaceDependency.dependent),
      )
      ..add(
        surface: depChild,
        parentId: depParent.surfaceId,
        relationToParent:
            SurfaceRelation(dependency: SurfaceDependency.dependent),
      )
      ..add(surface: independent, parentId: depChild.surfaceId);
  });

  group('Test adding Surfaces to tree', () {
    test('Add a SurfaceNode to Tree', () {
      tree.add(surface: grandparent);
      expect(tree.toList(), equals([grandparent]));
    });
    test('Add Surface to specific parent', () {
      tree
        ..add(surface: grandparent)
        ..add(surface: parent, parentId: grandparent.surfaceId);
      expect(
          tree
              .findNode(surfaceId: grandparent.surfaceId)
              .childNodes
              .map((SurfaceNode n) => n.surface),
          equals([parent]));
    });
    test('Make 3 generation tree', () {
      tree
        ..add(surface: grandparent)
        ..add(surface: parent, parentId: grandparent.surfaceId)
        ..add(surface: child, parentId: parent.surfaceId);
      expect(tree.toList(), equals([grandparent, parent, child]));
    });
    test('Remove middle generation, expect grandparent and child to remain',
        () {
      tree
        ..add(surface: grandparent)
        ..add(surface: parent, parentId: grandparent.surfaceId)
        ..add(surface: child, parentId: parent.surfaceId)
        ..remove(surfaceId: parent.surfaceId);
      expect(tree.toList(), equals([grandparent, child]));
    });
    test('Reparent child on grandparent via update()', () {
      tree
        ..add(surface: grandparent)
        ..add(surface: parent, parentId: grandparent.surfaceId)
        ..add(surface: child, parentId: parent.surfaceId)
        ..update(surface: child, parentId: grandparent.surfaceId);
      expect(
          tree
              .findNode(surfaceId: grandparent.surfaceId)
              .childNodes
              .map((SurfaceNode s) => s.surface)
              .toList(),
          equals([parent, child]));
    });
    test('Make child an orphan via update()', () {
      tree
        ..add(surface: grandparent)
        ..add(surface: parent, parentId: grandparent.surfaceId)
        ..add(surface: child, parentId: parent.surfaceId)
        ..update(surface: child);
      expect(
          tree.findNode(surfaceId: child.surfaceId).parentNode, equals(null));
    });
    test('Find spanning tree for condition from middle', () {
      // expect to find the spanning tree starting from the middle
      SurfaceTree depSpanTree = depTree.spanningTree(
          condition: condition, startNodeId: parent.surfaceId);
      expect(depSpanTree.toList(), equals([grandparent, depParent, depChild]));
    });
    test('Find spanning tree for condition from top', () {
      // expect to find the spanning tree starting from the top
      SurfaceTree depSpanTree = depTree.spanningTree(
          startNodeId: grandparent.surfaceId, condition: condition);
      expect(depSpanTree.toList(), equals([grandparent, depParent, depChild]));
    });
    test('Find empty spanning tree for condition from failing node', () {
      // but expect spanning tree starting on a node failing the condition to
      // be just the node
      expect(
          depTree.spanningTree(
              condition: condition, startNodeId: 'independent'),
          equals([independent]));
    });
  });
}
