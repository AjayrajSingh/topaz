// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:composition_delegate/composition_delegate.dart';
import 'package:test/test.dart';

void main() {
  CompositionDelegate setupCompositionDelegate() {
    CompositionDelegate compDelegate = CompositionDelegate(
        layoutContext:
            LayoutContext(size: Size(1280, 800), minSurfaceWidth: 320));
    return compDelegate;
  }

  group(
    'Test stack layout determination',
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
    },
  );
}
