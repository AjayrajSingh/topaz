// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.mondrian.dart/mondrian.dart';
import 'package:test/test.dart';

void main() {
  Composer composer = new Composer(
    layoutContext: new LayoutContext(size: Size(1280, 800)),
  );

  group(
    'Test layout for unrelated Surfaces',
    () {
      test('Layout determination for no Surfaces', () {
        expect(composer.getLayout(), equals([]));
      });
      test('Layout determination for one Surface', () {
        // expect a List, with one Layer, with one SurfaceLayout
        List<Layer> expectedLayout = <Layer>[
          Layer(
              element: SurfaceLayout(
                  x: 0, y: 0, w: 1280, h: 800, surfaceId: 'first'))
        ];
        composer
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first');
        expect(composer.getLayout(), equals(expectedLayout));
      });
      test('Layout determination for two Surfaces', () {
        Layer expectedUpper = Layer(
            element: SurfaceLayout(
                x: 0, y: 0, w: 1280, h: 800, surfaceId: 'second'));
        Layer expectedLower = Layer(
            element:
                SurfaceLayout(x: 0, y: 0, w: 1280, h: 800, surfaceId: 'first'));
        // expect a List of two Layers, with one SurfaceLayout in each
        List<Layer> expectedLayout = [expectedLower, expectedUpper];
        composer
          ..addSurface(surface: Surface(surfaceId: 'second'))
          ..focusSurface(surfaceId: 'second');
        expect(composer.getLayout(), equals(expectedLayout));
      });
    },
  );
}
