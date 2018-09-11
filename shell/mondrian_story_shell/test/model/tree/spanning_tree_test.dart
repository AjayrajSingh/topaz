// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// import 'dart:convert';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondrian/models/surface/surface.dart';
import 'package:mondrian/models/surface/surface_graph.dart';
import 'package:mondrian/models/surface/surface_properties.dart';
import 'package:mondrian/models/tree/spanning_tree.dart';
import 'package:mondrian/models/tree/tree.dart';

void main() {
  test('getCopresentSpanningTree with one surface in the graph', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    Surface parent =
        graph.addSurface('value', properties, '', relation, null, '');
    Tree<Surface> spanningTree = getCopresentSpanningTree(parent);
    expect(spanningTree.length, 1);
    expect(spanningTree.value, parent);
  });

  test('getCopresentSpanningTree from grandchild with 3 surfaces in the graph',
      () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    Surface parent =
        graph.addSurface('parent', properties, '', relation, null, '');
    Surface child =
        graph.addSurface('child', properties, 'parent', relation, null, '');
    Surface grandchild =
        graph.addSurface('grandchild', properties, 'child', relation, null, '');
    Tree<Surface> spanningTree = getCopresentSpanningTree(grandchild);

    expect(spanningTree.length, 3);
    expect(spanningTree.value, grandchild);
    List<Surface> children =
        spanningTree.map((Tree<Surface> node) => node.value).toList();
    expect(children.contains(child), true);
    expect(children.contains(parent), true);
  });

  test(
      'getCopresentSpanningTree from grandchild with 2 other unrelated surfaces in the graph',
      () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('parent', properties, '', relation, null, '')
      ..addSurface('child', properties, '', relation, null, '');
    Surface grandchild =
        graph.addSurface('grandchild', properties, '', relation, null, '');
    Tree<Surface> spanningTree = getCopresentSpanningTree(grandchild);

    expect(spanningTree.length, 1);
    expect(spanningTree.value, grandchild);
  });

  test(
      'getDependentSpanningTree from grandchild with 2 other unrelated surfaces in the graph',
      () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('parent', properties, '', relation, null, '')
      ..addSurface('child', properties, '', relation, null, '');
    Surface grandchild =
        graph.addSurface('grandchild', properties, '', relation, null, '');
    Tree<Surface> spanningTree = getDependentSpanningTree(grandchild);

    expect(spanningTree.length, 1);
    expect(spanningTree.value, grandchild);
  });

  test(
      'getDependentSpanningTree from grandchild with 2 other unrelated surfaces in the graph',
      () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('parent', properties, '', relation, null, '')
      ..addSurface('child', properties, '', relation, null, '');
    Surface grandchild =
        graph.addSurface('grandchild', properties, '', relation, null, '');
    Tree<Surface> spanningTree = getDependentSpanningTree(grandchild);

    expect(spanningTree.length, 1);
    expect(spanningTree.value, grandchild);
  });

  test('getDependentSpanningTrees', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('parent', properties, '', relation, null, '')
      ..addSurface('child', properties, '', relation, null, '');
    Surface grandchild =
        graph.addSurface('grandchild', properties, '', relation, null, '');
    List<Tree<Surface>> spanningTree =
        getDependentSpanningTrees(grandchild).flatten();

    expect(spanningTree.length, 1);
    expect(spanningTree.first.value, grandchild);
  });
}
