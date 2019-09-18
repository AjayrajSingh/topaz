// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:composition_delegate/composition_delegate.dart';
import 'package:test/test.dart';

void main() {
  CompositionDelegate setupCompositionDelegate() {
    CompositionDelegate compDelegate = CompositionDelegate(
        layoutContext:
            LayoutContext(size: Size(1280, 800), minSurfaceWidth: 320))
      ..setLayoutStrategy(
          layoutStrategy: layoutStrategyType.splitEvenlyStrategy);
    return compDelegate;
  }

  group(
    'Test Split layout determination',
    () {
      test('For no Surfaces is empty', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();
        expect(compDelegate.getLayout(), equals([]));
      });

      test('For one Surface is full screen', () {
        // expect a List, with one Layer, with one SurfaceLayout
        CompositionDelegate compDelegate = setupCompositionDelegate();

        List<Layer> expectedLayout = <Layer>[
          Layer(
              element: SurfaceLayout(
                  x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'first'))
        ];
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });

      test('For two Surfaces with no relationship is stacked', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();

        Layer expectedUpper = Layer(
            element: SurfaceLayout(
                x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'second'));
        Layer expectedLower = Layer(
            element: SurfaceLayout(
                x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'first'));
        // expect a List of two Layers, with one SurfaceLayout in each
        List<Layer> expectedLayout = [expectedLower, expectedUpper];
        // This test relies on the surface being focused in the correct order as the focus list is
        // maintained separaretly from what has been added to the tree.
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first')
          ..addSurface(surface: Surface(surfaceId: 'second'))
          ..focusSurface(surfaceId: 'second');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });

      test('For two related Surfaces is a 50/50 split', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();
        List<SurfaceLayout> surfaces = [
          SurfaceLayout(x: 0.0, y: 0.0, w: 640.0, h: 800.0, surfaceId: 'first'),
          SurfaceLayout(
              x: 640.0, y: 0.0, w: 640.0, h: 800.0, surfaceId: 'second'),
        ];

        Layer expectedLayout = Layer.fromList(elements: surfaces);
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..addSurface(
              surface: Surface(
                surfaceId: 'second',
                metadata: {},
              ),
              parentId: 'first')
          ..focusSurface(surfaceId: 'second');
        expect(compDelegate.getLayout(), equals([expectedLayout]));
      });

      test(
          'For four Surfaces, 3 children with the same parent, is split into quarters vertically',
          () {
        CompositionDelegate compDelegate = setupCompositionDelegate();
        List<SurfaceLayout> surfaces = [
          SurfaceLayout(x: 0.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'first'),
          SurfaceLayout(
              x: 320.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'second'),
          SurfaceLayout(
              x: 640.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'third'),
          SurfaceLayout(
              x: 960.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'fourth'),
        ];

        Layer expectedLayout = Layer.fromList(elements: surfaces);
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..addSurface(
              surface: Surface(
                surfaceId: 'second',
                metadata: {},
              ),
              parentId: 'first')
          ..addSurface(
              surface: Surface(
                surfaceId: 'third',
                metadata: {},
              ),
              parentId: 'first')
          ..addSurface(
              surface: Surface(
                surfaceId: 'fourth',
                metadata: {},
              ),
              parentId: 'first')
          ..focusSurface(surfaceId: 'fourth');
        expect(compDelegate.getLayout(), equals([expectedLayout]));
      });
    },
  );
}
