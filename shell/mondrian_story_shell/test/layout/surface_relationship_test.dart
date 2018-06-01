// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mondrian/layout_model.dart';
import 'package:mondrian/model.dart';
import 'package:mondrian/copresent_layout.dart' as copresent_layout;
import 'package:mondrian/positioned_surface.dart';
import 'package:mondrian/surface_details.dart';

import '../layout_test_utils.dart' as test_util;

const double maxHeight = 400.0;
const double maxWidth = 400.0;

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
    Surface root =
        graph.addSurface('root_of_test', properties, '', surfaceRelation, '');

    List<Surface> surfaces = [
      root,
    ];
    List<PositionedSurface> positionedSurfaces =
        copresent_layout.layoutSurfaces(
            null /* BuildContext */, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight, width: maxWidth, topLeft: const Offset(0.0, 0.0));
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
    Surface root =
        graph.addSurface('root_of_test', properties, '', surfaceRelation, '');

    // properties for the copresent surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface copresentSurface = graph.addSurface(
        'copresentSurface', properties, 'root_of_test', surfaceRelation, '');

    List<Surface> surfaces = [
      root,
      copresentSurface,
    ];
    List<PositionedSurface> positionedSurfaces =
        copresent_layout.layoutSurfaces(
            null /* BuildContext */, surfaces, layoutModel);
    expect(positionedSurfaces.length, 2);

    expect(positionedSurfaces[0].surface, root);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight,
        width: maxWidth * 0.5,
        topLeft: const Offset(0.0, 0.0));

    expect(positionedSurfaces[1].surface, copresentSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[1],
        height: maxHeight,
        width: maxWidth * 0.5,
        topLeft: const Offset(maxWidth * 0.5, 0.0));
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
    Surface root =
        graph.addSurface('root_of_test', properties, '', surfaceRelation, '');

    // properties for the sequential surface
    properties = new SurfaceProperties();
    surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.sequential,
      dependency: SurfaceDependency.none,
      emphasis: 1.0,
    );
    Surface sequentialSurface = graph.addSurface(
        'copresentSurface', properties, 'root_of_test', surfaceRelation, '');

    List<Surface> surfaces = [
      root,
      sequentialSurface,
    ];
    List<PositionedSurface> positionedSurfaces =
        copresent_layout.layoutSurfaces(
            null /* BuildContext */, surfaces, layoutModel);
    expect(positionedSurfaces.length, 1);

    expect(positionedSurfaces[0].surface, sequentialSurface);
    test_util.assertSurfaceProperties(positionedSurfaces[0],
        height: maxHeight, width: maxWidth, topLeft: const Offset(0.0, 0.0));
  });
}
