// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'model.dart';
import 'simulated_positioned.dart';
import 'story_relationships.dart';
import 'surface_widget.dart';

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  /// SurfaceLayout
  SurfaceLayout({Key key}) : super(key: key);

  @override
  _SurfaceLayoutState createState() => new _SurfaceLayoutState();
}

/// Maintains state for the avaialble views to display.
class _SurfaceLayoutState extends State<SurfaceLayout> {
  /// Candidate view for removal
  Surface surfaceToBeRemoved;

  /// Candidate view for removal's original relationship
  String surfaceToBeRemovedRelationship;

  /// Layout offset
  double offset = 0.0;

  void _endDrag(Surface surface, SimulatedDragEndDetails details) {
    // HACK(alangardner): Harcoded distances for swipe gesture
    // to avoid complicated layout work for this throwaway version.
    Offset expectedOffset =
        details.offset + (details.velocity.pixelsPerSecond / 5.0);
    // Only remove if greater than threshold ant not root surface.
    if (expectedOffset.distance > 200.0) {
      setState(() {
        // Need to capture old relationship before we remove from SurfaceGraph
        String relationship = surface.relationship;
        if (surface.remove()) {
          surfaceToBeRemoved = surface;
          surfaceToBeRemovedRelationship = relationship;
        }
      });
    }
  }

  Widget _surface({Surface surface, Rect rect, Rect initRect}) =>
      new SimulatedPositioned(
        key: new ObjectKey(surface),
        rect: rect,
        initRect: initRect,
        child: new ScopedModel<Surface>(
            model: surface, child: new SurfaceWidget()),
        onDragEnd: (SimulatedDragEndDetails details) {
          _endDrag(surface, details);
        },
      );

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          new ScopedModelDescendant<SurfaceGraph>(builder:
              (BuildContext context, Widget child, SurfaceGraph graph) {
            final Offset topLeft = Offset.zero;
            final Offset offscreen = constraints.biggest.topRight(topLeft);
            final Rect full = topLeft & constraints.biggest;
            final Rect left = topLeft & new Size(full.width / 3.0, full.height);
            final Rect right = (topLeft + left.topRight) &
                new Size(full.width - left.width, full.height);
            final List<Widget> childViews = <Widget>[];
            Surface focused = graph.focused;
            List<Surface> displayedSurfaces = new List<Surface>();
            if (graph.size == 0 || focused == null) {
              // Add no children
            } else if (graph.size == 1) {
              _log('BUILD sole');
              displayedSurfaces.add(focused);
              childViews.add(new SimulatedPositioned(
                key: new ObjectKey(focused),
                rect: full,
                child: new ScopedModel<Surface>(
                  model: focused,
                  child: new SurfaceWidget(chrome: false),
                ),
              ));
            } else if (focused.relationship == kSerial) {
              _log('BUILD serial: $focused');
              displayedSurfaces.add(focused);
              childViews.add(_surface(
                surface: focused,
                rect: full,
                initRect: full.shift(offscreen),
              ));
            } else if (focused.relationship == kHierarchical) {
              _log('BUILD hierarchical: ${focused.parent} $focused ');
              displayedSurfaces.add(focused);
              displayedSurfaces.add(focused.parent);
              childViews.add(_surface(
                surface: focused.parent,
                rect: left,
                initRect: left.shift(offscreen),
              ));
              childViews.add(_surface(
                surface: focused,
                rect: right,
                initRect: right.shift(offscreen),
              ));
            } else {
              _log('ERROR: Unknown relationship: ${focused.relationship}');
            }

            for (Surface surface in graph.focusedSurfaceHistory
                .where((Surface s) => !displayedSurfaces.contains(s))) {
              childViews.insert(
                0,
                new SimulatedPositioned(
                  key: new ObjectKey(surface),
                  rect: full,
                  child: new ScopedModel<Surface>(
                    model: surface,
                    child: new SurfaceWidget(interactable: false),
                  ),
                ),
              );
            }

            // Outgoing views animate to/from the right
            if (surfaceToBeRemoved != null) {
              Rect offscreenRect = offscreen &
                  (surfaceToBeRemovedRelationship == kSerial
                      ? full.size
                      : right.size);
              childViews.add(new SimulatedPositioned(
                key: new ObjectKey(surfaceToBeRemoved),
                rect: offscreenRect,
                child: new ScopedModel<Surface>(
                  model: surfaceToBeRemoved,
                  child: new SurfaceWidget(interactable: false),
                ),
              ));
            }
            return new Stack(children: childViews);
          }));
}
