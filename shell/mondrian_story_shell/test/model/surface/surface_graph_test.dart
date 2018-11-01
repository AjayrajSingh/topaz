// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mondrian/models/surface/surface.dart';
import 'package:mondrian/models/surface/surface_graph.dart';
import 'package:mondrian/models/surface/surface_properties.dart';

class MockInterfaceHandle extends Mock implements InterfaceHandle<ViewOwner> {}

void main() {
  test('toJson and back again with a single surface', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('value', properties, '', relation, null, '')
      ..connectView('value', new MockInterfaceHandle())
      ..focusSurface('value');
    expect(graph.focusStack.length, 1);
    String encoded = json.encode(graph);

    Map<String, dynamic> decoded = json.decode(encoded);
    SurfaceGraph decodedGraph = new SurfaceGraph.fromJson(decoded);

    expect(decodedGraph.focusStack.length, 1);
    Surface surface = decodedGraph.focusStack.first;
    expect(surface.node.value, 'value');
    expect(surface.parent, null);
    expect(surface.relation.arrangement, SurfaceArrangement.copresent);
    expect(surface.relation.dependency, SurfaceDependency.dependent);
    expect(surface.relation.emphasis, 0.12);
    expect(surface.properties.containerLabel, 'containerLabel');
  });

  test('toJson and back again with two surfaces', () {
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
      ..connectView('parent', new MockInterfaceHandle())
      ..focusSurface('parent');
    expect(graph.focusStack.length, 1);

    properties = new SurfaceProperties(containerLabel: 'containerLabel');
    relation = new SurfaceRelation(
      emphasis: 0.5,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('child', properties, 'parent', relation, null, '')
      ..connectView('child', new MockInterfaceHandle())
      ..focusSurface('child');
    expect(graph.focusStack.length, 2);

    String encoded = json.encode(graph);

    Map<String, dynamic> decoded = json.decode(encoded);
    SurfaceGraph decodedGraph = new SurfaceGraph.fromJson(decoded);

    expect(decodedGraph.focusStack.length, 2);
    Surface surface = decodedGraph.focusStack.first;
    expect(surface.node.value, 'parent');
    expect(surface.node.parent.value, null);

    // expect(surface.parentId, null);
    expect(surface.relation.arrangement, SurfaceArrangement.copresent);
    expect(surface.relation.dependency, SurfaceDependency.dependent);
    expect(surface.relation.emphasis, 0.12);
    expect(surface.properties.containerLabel, 'containerLabel');
    expect(surface.children.length, 1);
    expect(surface.children.first.node.value, 'child');

    Surface secondSurface = decodedGraph.focusStack.last;
    expect(secondSurface.node.value, 'child');
    expect(secondSurface.parentId, 'parent');
    expect(secondSurface.relation.arrangement, SurfaceArrangement.copresent);
    expect(secondSurface.relation.dependency, SurfaceDependency.dependent);
    expect(secondSurface.relation.emphasis, 0.5);
    expect(secondSurface.properties.containerLabel, 'containerLabel');
  });

  test('toJson and back again with one surface with two children', () {
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
      ..connectView('parent', new MockInterfaceHandle())
      ..focusSurface('parent');
    expect(graph.focusStack.length, 1);

    properties = new SurfaceProperties(containerLabel: 'containerLabel');
    relation = new SurfaceRelation(
      emphasis: 0.5,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('child1', properties, 'parent', relation, null, '')
      ..connectView('child1', new MockInterfaceHandle())
      ..focusSurface('child1');
    expect(graph.focusStack.length, 2);

    properties = new SurfaceProperties(containerLabel: 'containerLabel');
    relation = new SurfaceRelation(
      emphasis: 0.0,
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('child2', properties, 'parent', relation, null, '')
      ..connectView('child2', new MockInterfaceHandle())
      ..focusSurface('child2');
    expect(graph.focusStack.length, 3);

    String encoded = json.encode(graph);

    Map<String, dynamic> decoded = json.decode(encoded);
    SurfaceGraph decodedGraph = new SurfaceGraph.fromJson(decoded);

    expect(decodedGraph.focusStack.length, 3);
    Surface surface = decodedGraph.focusStack.first;
    expect(surface.node.value, 'parent');
    expect(surface.node.parent.value, null);
    expect(surface.relation.arrangement, SurfaceArrangement.copresent);
    expect(surface.relation.dependency, SurfaceDependency.dependent);
    expect(surface.relation.emphasis, 0.12);
    expect(surface.properties.containerLabel, 'containerLabel');
    expect(surface.children.length, 2);
    List<String> children = [];
    for (Surface surface in surface.children) {
      children.add(surface.node.value);
    }
    expect(children.first, 'child1');
    expect(children.last, 'child2');

    Surface secondSurface = decodedGraph.focusStack.toList()[1];
    expect(secondSurface.node.value, 'child1');
    expect(secondSurface.parentId, 'parent');
    expect(secondSurface.relation.arrangement, SurfaceArrangement.copresent);
    expect(secondSurface.relation.dependency, SurfaceDependency.dependent);
    expect(secondSurface.relation.emphasis, 0.5);
    expect(secondSurface.properties.containerLabel, 'containerLabel');

    Surface thirdSurface = decodedGraph.focusStack.last;
    expect(thirdSurface.node.value, 'child2');
    expect(thirdSurface.parentId, 'parent');
    expect(thirdSurface.relation.arrangement, SurfaceArrangement.ontop);
    expect(thirdSurface.relation.dependency, SurfaceDependency.dependent);
    expect(thirdSurface.relation.emphasis, 0.0);
    expect(thirdSurface.properties.containerLabel, 'containerLabel');
  });

  test('external surfaces are found by resummon dismissed checks', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties externalProp =
        new SurfaceProperties(source: ModuleSource.external$);
    graph
      ..addSurface('parent', new SurfaceProperties(), '', new SurfaceRelation(),
          null, '')
      ..connectView('parent', new MockInterfaceHandle())
      ..focusSurface('parent')
      // Now add external surface
      ..addSurface(
          'external', externalProp, 'parent', new SurfaceRelation(), null, '')
      ..connectView('external', new MockInterfaceHandle())
      ..focusSurface('external')
      // Now dismiss the external surface
      ..dismissSurface('external');
    // expect that there is a dismissed external associated with the parent
    expect(graph.externalSurfaces(surfaceId: 'parent'), ['external']);
  });

  test('duplicate surface add', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('value', properties, '', relation, null, '')
      ..connectView('value', new MockInterfaceHandle())
      ..focusSurface('value');
    expect(graph.treeSize, 2);

    graph
      ..addSurface('value', properties, '', relation, null, '')
      ..connectView('value', new MockInterfaceHandle())
      ..focusSurface('value');
    expect(graph.treeSize, 2);
  });

  test('duplicate child surface add', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('value', properties, '', relation, null, '')
      ..connectView('value', new MockInterfaceHandle())
      ..focusSurface('value');
    expect(graph.treeSize, 2);

    graph
      ..addSurface('value.child', properties, '', relation, null, '')
      ..connectView('value.child', new MockInterfaceHandle())
      ..focusSurface('value.child');
    expect(graph.treeSize, 3);

    graph
      ..addSurface('value.child', properties, '', relation, null, '')
      ..connectView('value.child', new MockInterfaceHandle())
      ..focusSurface('value.child');
    expect(graph.treeSize, 3);
  });

  test('duplicate child surface add', () {
    SurfaceGraph graph = new SurfaceGraph();
    SurfaceProperties properties =
        new SurfaceProperties(containerLabel: 'containerLabel');
    SurfaceRelation relation = new SurfaceRelation(
      emphasis: 0.12,
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
    );
    graph
      ..addSurface('value', properties, '', relation, null, '')
      ..connectView('value', new MockInterfaceHandle())
      ..focusSurface('value');
    expect(graph.treeSize, 2);

    graph
      ..addSurface('value.child', properties, '', relation, null, '')
      ..connectView('value.child', new MockInterfaceHandle())
      ..focusSurface('value.child');
    expect(graph.treeSize, 3);

    MockInterfaceHandle handle = new MockInterfaceHandle();
    graph
      ..addSurface('value.child', properties, '', relation, null, '')
      ..connectView('value.child', handle)
      ..focusSurface('value.child');
    expect(graph.treeSize, 3);
    verifyZeroInteractions(handle);
  });
}
