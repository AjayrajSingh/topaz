// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondrian/models/surface/surface.dart';
import 'package:mondrian/models/surface/surface_graph.dart';
import 'package:mondrian/models/surface/surface_properties.dart';
import 'package:mondrian/models/surface/surface_relation_util.dart';
import 'package:mondrian/models/tree/tree.dart';

void main() {
  test('toJson and fromJson', () {
    SurfaceGraph graph = new SurfaceGraph();
    Tree parent = new Tree<String>(value: null);
    Tree node = new Tree<String>(value: 'value');
    Tree child = new Tree<String>(value: 'childValue');
    parent.add(node);
    node.add(child);
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    Surface surface = new Surface(graph, node, properties, relation, null, '');
    String encoded = json.encode(surface);
    Map decodedJson = json.decode(encoded);
    Surface decodedSurface = new Surface.fromJson(decodedJson, graph);
    expect(decodedSurface.node.value, 'value');
    expect(decodedSurface.isParentRoot, true);
    expect(decodedSurface.relation.emphasis, 0.12);
    expect(decodedSurface.relation.arrangement, SurfaceArrangement.copresent);
    expect(decodedSurface.relation.dependency, SurfaceDependency.dependent);
    expect(decodedSurface.properties.containerLabel, 'containerLabel');
    expect(decodedSurface.compositionPattern, null);
  });

  test('encode and decode surfaceRelation', () {
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.5,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    Map<String, String> relationMap = SurfaceRelationUtil.toMap(relation);
    SurfaceRelation decodedRelation = SurfaceRelationUtil.decode(relationMap);
    expect(decodedRelation.arrangement, SurfaceArrangement.copresent);
    expect(decodedRelation.dependency, SurfaceDependency.dependent);
    expect(decodedRelation.emphasis, 0.5);
  });
}
