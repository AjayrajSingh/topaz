// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:composition_delegate/src/internal/layout_logic/_layout_strategy.dart';

/// The default strategy, returns each Surface in a Stack
class StackStrategy extends LayoutStrategy {
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

  @override
  List<Layer> getLayout({
    LinkedHashSet focusedSurfaces,
    Set<String> hiddenSurfaces,
    LayoutContext layoutContext,
    List<Layer> previousLayout,
    SurfaceTree surfaceTree,
  }) {
    this.focusedSurfaces = focusedSurfaces;
    this.hiddenSurfaces = hiddenSurfaces;
    this.layoutContext = layoutContext;
    this.previousLayout = previousLayout;
    this.surfaceTree = surfaceTree;
    List<Layer> layout = <Layer>[];
    // Relies purely on the focused surfaces rather than what's in the graph.
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
    return layout;
  }
}
