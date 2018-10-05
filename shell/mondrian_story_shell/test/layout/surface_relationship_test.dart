// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mondrian/models/layout_model.dart';
import 'package:mondrian/layout/copresent_layout.dart' as copresent_layout;
import 'package:mondrian/models/surface/positioned_surface.dart';
import 'package:mondrian/models/surface/surface.dart';
import 'package:mondrian/models/surface/surface_graph.dart';
import 'package:mondrian/models/surface/surface_properties.dart';

import '../layout_test_utils.dart' as test_util;

class MockInterfaceHandle extends Mock implements InterfaceHandle<ViewOwner> {}

void main() {
  LayoutModel layoutModel = new LayoutModel();

  test('Single surface', () {
    SurfaceGraph graph = new SurfaceGraph();

    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));
  });

  test('Copresent 2 surfaces', () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for the copresent surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface copresentSurface = graph.addSurface('copresentSurface', properties,
        'root_of_test', surfaceRelation, '', '');
    graph.connectView('copresentSurface', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      copresentSurface,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 0.5, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, copresentSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: 1.0, width: 0.5, topLeft: const Offset(0.5, 0.0));
  });

  test('Sequential surfaces', () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for the sequential surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.sequential,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface sequentialSurface = graph.addSurface('copresentSurface', properties,
        'root_of_test', surfaceRelation, '', '');
    graph.connectView('copresentSurface', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      sequentialSurface,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);

    expect(positionedSurfaces[0].surface, sequentialSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));
  });

  test('one surface ontop of another surface', () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for the ontop surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface ontopSurface = graph.addSurface(
        'ontop', properties, 'root_of_test', surfaceRelation, '', '');
    graph.connectView('ontop', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      ontopSurface,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, ontopSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));
  });

  test('two surfaces in copresent and one brought ontop of the root surface',
      () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for root surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface copresentSurface = graph.addSurface(
        'copresent', properties, 'root_of_test', surfaceRelation, '', '');
    graph.connectView('copresent', new MockInterfaceHandle());

    // properties for the ontop surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface ontopSurface = graph.addSurface(
        'ontop', properties, 'root_of_test', surfaceRelation, '', '');
    graph.connectView('ontop', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      copresentSurface,
      ontopSurface,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 0.5, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, copresentSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: 1.0, width: 0.5, topLeft: const Offset(0.5, 0.0));

    expect(positionedSurfaces[2].surface, ontopSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[2],
        height: 1.0, width: 0.5, topLeft: const Offset(0.0, 0.0));
  });

  test(
      'two surfaces in copresent and one brought ontop of the copresent surface',
      () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for root surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface copresentSurface = graph.addSurface(
        'copresent', properties, 'root_of_test', surfaceRelation, '', '');
    graph.connectView('copresent', new MockInterfaceHandle());

    // properties for the ontop surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface ontopSurface = graph.addSurface(
        'ontop', properties, 'copresent', surfaceRelation, '', '');
    graph.connectView('ontop', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      copresentSurface,
      ontopSurface,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 0.5, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, copresentSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: 1.0, width: 0.5, topLeft: const Offset(0.5, 0.0));

    expect(positionedSurfaces[2].surface, ontopSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[2],
        height: 1.0, width: 0.5, topLeft: const Offset(0.5, 0.0));
  });

  test('three surfaces on top of each other', () {
    SurfaceGraph graph = new SurfaceGraph();

    // properties for root surface
    SurfaceProperties properties = new SurfaceProperties();
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.none,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface root = graph.addSurface(
        'root_of_test', properties, '', surfaceRelation, '', '');
    graph.connectView('root_of_test', new MockInterfaceHandle());

    // properties for root surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface firstOnTop = graph.addSurface(
        'ontop1', properties, 'root_of_test', surfaceRelation, '', '');
    graph.connectView('ontop1', new MockInterfaceHandle());

    // properties for the ontop surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.ontop,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface secondOntop = graph.addSurface(
        'ontop2', properties, 'ontop1', surfaceRelation, '', '');
    graph.connectView('ontop2', new MockInterfaceHandle());

    List<Surface> surfaces = [
      root,
      firstOnTop,
      secondOntop,
    ];
    List<PositionedSurface> positionedSurfaces = copresent_layout
        .layoutSurfaces(null /* BuildContext */, graph, surfaces, layoutModel);
    expect(positionedSurfaces.length, 3);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, firstOnTop);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[2].surface, secondOntop);
    test_util.assertSurfaceProperties(positionedSurfaces[2],
        height: 1.0, width: 1.0, topLeft: const Offset(0.0, 0.0));
  });
}
