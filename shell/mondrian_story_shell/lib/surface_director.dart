// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'model.dart';
import 'child_view.dart';
import 'copresent_layout.dart';
import 'surface_form.dart';
import 'surface_space.dart';
import 'tree.dart';

const double _kFadeToDepthRatio = 3.0;

void _log(String msg) {
  print('[MondrianFlutter] Director $msg');
}

/// Directs the layout of the SurfaceSpace
class SurfaceDirector extends StatefulWidget {
  @override
  _SurfaceDirectorState createState() => new _SurfaceDirectorState();
}

class _SurfaceDirectorState extends State<SurfaceDirector> {
  final Map<Surface, SurfaceForm> _forms = <Surface, SurfaceForm>{};

  SurfaceForm _form(PositionedSurface ps, double depth, Offset offscreen) =>
      new SurfaceForm.single(
        key: new GlobalObjectKey(ps.surface),
        child: new MondrianChildView(
          connection: ps.surface.connection,
          interactable: depth <= 0.0 ? true : false,
          fade: (depth * _kFadeToDepthRatio).clamp(0.0, 1.0),
        ),
        position: ps.position,
        initPosition: ps.position.shift(offscreen),
        depth: depth,
        friction: depth > 0.0
            ? kDragFrictionInfinite
            : ps.surface.canDismiss()
                ? kDragFrictionNone
                : (Offset offset, Offset delta) =>
                    delta / math.max(1.0, offset.distanceSquared / 100.0),
        onPositioned: () {
          if (ps.surface.dismissed) {
            setState(() {
              _forms.remove(ps.surface);
              // TODO(alangardner): Callback to notify framework
            });
          }
        },
        onDragStarted: () {
          // Bring dragged items above
          setState(() {
            _forms[ps.surface] = _form(
                new PositionedSurface(
                    surface: ps.surface, position: ps.position),
                -0.1,
                offscreen);
          });
        },
        onDragFinished: (Offset offset, Velocity velocity) {
          // HACK(alangardner): Harcoded distances for swipe
          // gesture to avoid complicated layout work for this
          // throwaway version.
          Offset expectedOffset = offset + (velocity.pixelsPerSecond / 5.0);
          // Only remove if greater than threshold
          if (expectedOffset.distance > 200.0) {
            setState(() {
              _forms[ps.surface] = _form(
                  new PositionedSurface(
                      surface: ps.surface,
                      position: ps.position.shift(offscreen)),
                  -0.1,
                  Offset.zero);
            });
            ps.surface.dismiss();
          } else {
            // HACK: Force relayout to reset position and depth
            setState(() {
              _forms.remove(ps.surface);
            });
          }
        },
      );

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.biggest.isInfinite || constraints.biggest.isEmpty) {
            return new Container();
          }
          _log('Build');
          final Offset offscreen = constraints.biggest.topRight(Offset.zero);
          return new SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: new ScopedModelDescendant<SurfaceGraph>(
              builder:
                  (BuildContext context, Widget child, SurfaceGraph graph) {
                List<Surface> focusStack = graph.focusStack.toList();
                List<Surface> placedSurfaces = <Surface>[];
                double depth = 0.0;
                // HACK(alangardner): Used to create illusion of symmetry
                BoxConstraints adjustedConstraints = new BoxConstraints(
                    minWidth: constraints.minWidth,
                    minHeight: constraints.minHeight,
                    maxHeight: constraints.maxHeight,
                    maxWidth: constraints.maxWidth - 12.0);
                while (focusStack.isNotEmpty) {
                  layoutSurfaces(context, adjustedConstraints, focusStack)
                      .forEach((PositionedSurface ps) {
                    if (!placedSurfaces.contains(ps.surface)) {
                      placedSurfaces.add(ps.surface);
                      double oldDepth = _forms[ps.surface]?.depth ?? 0.0;
                      _forms[ps.surface] = _form(
                          ps, oldDepth < 0.0 ? oldDepth : depth, offscreen);
                    }
                  });
                  depth = (depth + 0.1).clamp(0.0, 1.0);
                  while (focusStack.isNotEmpty &&
                      placedSurfaces.contains(focusStack.last)) {
                    focusStack.removeLast();
                  }
                }
                Forest<Surface> dependentSpanningTrees = new Forest<Surface>();
                // The actual node doesn't matter
                if (placedSurfaces.length > 0) {
                  // The actual surface doesn't matter
                  dependentSpanningTrees =
                      placedSurfaces.first.getDependentSpanningTrees();

                  /// prune non-visible surfaces
                  dependentSpanningTrees.flatten().forEach((Tree<Surface> t) {
                    if (!placedSurfaces.contains(t.value)) {
                      dependentSpanningTrees.remove(t);
                    }
                  });
                }
                SurfaceSpace space = new SurfaceSpace(
                    forms: dependentSpanningTrees
                        .mapForest((Surface s) => _forms[s]));

                _forms.clear(); // need to get rid of removed surfaces
                return space;
              },
            ),
          );
        },
      );
}
