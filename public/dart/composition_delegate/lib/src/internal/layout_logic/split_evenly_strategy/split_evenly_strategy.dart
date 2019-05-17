// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:composition_delegate/src/internal/layout_logic/_layout_strategy.dart';

/// Strategy for splitting the space evenly amongst the available Surfaces,
/// like a tiling window manager.
class SplitEvenStrategy extends LayoutStrategy {
  /// The snapshot of ordered set of focused Surfaces in the Story provided to
  /// the layout strategy
  LinkedHashSet focusedSurfaces;

  /// The snapshot of the set of hidden Surfaces in the Story provided to the
  /// layout strategy
  Set<String> hiddenSurfaces;

  /// The snapshot of the current layoutContext e.g. viewport size provided to
  /// the layout strategy
  LayoutContext layoutContext;

  /// The previously determined layout (not necessarily by this strategy)
  List<Layer> previousLayout;

  /// The snapshot of the surface tree describing relationships between
  /// surfaces in the story.
  SurfaceTree surfaceTree;

  /// Returns the layout for the split even strategy given the current context
  @override
  List<Layer> getLayout({
    LinkedHashSet focusedSurfaces,
    Set<String> hiddenSurfaces,
    LayoutContext layoutContext,
    List<Layer> previousLayout,
    SurfaceTree surfaceTree,
  }) {
    List<Layer> layout = <Layer>[];
    Layer layer = Layer();
    int surfaceIndex = 0;
    SurfaceTree spanningTree = surfaceTree.spanningTree(
      startNodeId: focusedSurfaces.last,
      condition: (node) => true,
    );
    if (spanningTree.length > 1) {
      double splitSize = layoutContext.size.width / spanningTree.length;
      for (Surface surface in spanningTree) {
        layer.add(SurfaceLayout(
          x: surfaceIndex * splitSize,
          y: 0.0,
          w: splitSize,
          h: layoutContext.size.height,
          surfaceId: surface.surfaceId,
        ));
        surfaceIndex += 1;
      }
      layout.add(layer);
    } else {
      for (String id in focusedSurfaces.toList()) {
        layout.add(
          Layer(
            element: SurfaceLayout(
              x: 0.0,
              y: 0.0,
              w: layoutContext.size.width,
              h: layoutContext.size.height,
              surfaceId: id,
            ),
          ),
        );
      }
    }
    return layout;
  }
}
