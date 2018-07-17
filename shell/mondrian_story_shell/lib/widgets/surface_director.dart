// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import '../layout/container_layout.dart' as container;
import '../layout/copresent_layout.dart' as copresent;
import '../layout/pattern_layout.dart' as pattern;
import '../models/inset_manager.dart';
import '../models/layout_model.dart';
import '../models/surface/positioned_surface.dart';
import '../models/surface/surface.dart';
import '../models/surface/surface_form.dart';
import '../models/tree.dart';
import 'mondrian_child_view.dart';

import 'surface_stage.dart';

/// Directs the layout of the SurfaceSpace
class SurfaceDirector extends StatefulWidget {
  @override
  _SurfaceDirectorState createState() => new _SurfaceDirectorState();
}

class _SurfaceDirectorState extends State<SurfaceDirector> {
  final Map<Surface, SurfaceForm> _prevForms = <Surface, SurfaceForm>{};
  final List<Surface> _draggedSurfaces = <Surface>[];
  final List<SurfaceForm> _orphanedForms = <SurfaceForm>[];

  SurfaceForm _form(
    PositionedSurface ps,
    double depth,
    FractionalOffset offscreen,
  ) =>
      new SurfaceForm.single(
        key: new GlobalObjectKey(ps.surface),
        child: MondrianChildView(
          surface: ps.surface,
          interactable: depth <= 0.0,
        ),
        position: ps.position,
        initPosition: ps.position.shift(new Offset(offscreen.dx, offscreen.dy)),
        depth: _draggedSurfaces.contains(ps.surface) ? -0.1 : depth,
        friction: depth > 0.0
            ? kDragFrictionInfinite
            : ps.surface.canDismiss()
                ? kDragFrictionNone
                : (Offset offset, Offset delta) =>
                    delta / math.max(1.0, offset.distanceSquared / 100.0),
        onDragStarted: () {
          setState(() {
            _draggedSurfaces.add(ps.surface);
          });
        },
        onDragFinished: (Offset offset, Velocity velocity) {
          Offset expectedOffset = offset + (velocity.pixelsPerSecond / 5.0);
          // Only remove if greater than threshold
          if (expectedOffset.distance > 200.0) {
            // HACK(alangardner): Hardcoded distances for swipe gesture to
            // avoid complicated layout work.
            ps.surface.dismiss();
          }
          setState(() {
            _draggedSurfaces.remove(ps.surface);
          });
        },
      );

  SurfaceForm _orphanedForm(
          Surface surface, SurfaceForm form, FractionalOffset offscreen) =>
      new SurfaceForm.single(
        key: form.key,
        child: MondrianChildView(
          surface: surface,
          interactable: false,
        ),
        position: form.position.shift(new Offset(offscreen.dx, offscreen.dy)),
        initPosition: form.initPosition,
        depth: form.depth,
        friction: kDragFrictionInfinite,
        onPositioned: () {
          // TODO(alangardner): Callback to notify framework
          setState(() {
            _orphanedForms.removeWhere((SurfaceForm f) => f.key == form.key);
          });
        },
      );

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<InsetManager>(
        builder: (
          BuildContext context,
          Widget child,
          InsetManager insetManager,
        ) =>
            ScopedModelDescendant<LayoutModel>(
              builder: (
                BuildContext context,
                Widget child,
                LayoutModel layoutModel,
              ) =>
                  ScopedModelDescendant<SurfaceGraph>(
                    builder: (
                      BuildContext context,
                      Widget child,
                      SurfaceGraph graph,
                    ) =>
                        _buildStage(
                          context,
                          FractionalOffset.topRight,
                          insetManager,
                          layoutModel,
                          graph,
                        ),
                  ),
            ),
      );

  Widget _buildStage(
    BuildContext context,
    FractionalOffset offscreen,
    InsetManager insetManager,
    LayoutModel layoutModel,
    SurfaceGraph graph,
  ) {
    Map<Surface, SurfaceForm> placedSurfaces = <Surface, SurfaceForm>{};
    List<Surface> focusStack = graph.focusStack.toList();
    double depth = 0.0;
    while (focusStack.isNotEmpty) {
      List<PositionedSurface> positionedSurfaces = <PositionedSurface>[];
      if (focusStack.isNotEmpty) {
        Surface last = focusStack.last;
        // purposefully giving compositionPattern top billing
        // here to avoid any codelab surprises but we will have
        // to harmonize this logic in future
        // TODO: (djmurphy, jphsiao)
        if (last.compositionPattern != null &&
            last.compositionPattern.isNotEmpty) {
          positionedSurfaces = pattern.layoutSurfaces(
            context,
            focusStack,
            layoutModel,
          );
        } else if (last.properties.containerMembership != null &&
            last.properties.containerMembership.isNotEmpty) {
          positionedSurfaces = container.layoutSurfaces(
            context,
            last,
            layoutModel,
          );
        } else {
          positionedSurfaces = copresent.layoutSurfaces(
            context,
            focusStack,
            layoutModel,
          );
        }
      }
      for (PositionedSurface ps in positionedSurfaces) {
        if (!placedSurfaces.keys.contains(ps.surface)) {
          _prevForms.remove(ps.surface);
          FractionalOffset surfaceOrigin = positionedSurfaces.length > 1
              ? offscreen
              : FractionalOffset.topLeft;
          if (ps.surface.relation.arrangement == SurfaceArrangement.ontop) {
            // Surfaces that are ontop will be placed above the current depth
            // TODO(jphsiao): Revisit whether ontop should be placed on top of
            // all surfaces or if it should push its parent back in z.
            placedSurfaces[ps.surface] = _form(ps, -1.0, surfaceOrigin);
          } else {
            placedSurfaces[ps.surface] = _form(ps, depth, surfaceOrigin);
          }
        }
      }
      depth = (depth + 0.1).clamp(0.0, 1.0);
      while (focusStack.isNotEmpty &&
          placedSurfaces.keys.contains(focusStack.last)) {
        focusStack.removeLast();
      }
    }
    Forest<Surface> dependentSpanningTrees = new Forest<Surface>();
    // The actual node doesn't matter
    if (placedSurfaces.isNotEmpty) {
      // The actual surface doesn't matter
      dependentSpanningTrees =
          placedSurfaces.keys.first.getDependentSpanningTrees();

      /// prune non-visible surfaces
      for (Tree<Surface> t in dependentSpanningTrees.flatten()) {
        if (!placedSurfaces.keys.contains(t.value)) {
          dependentSpanningTrees.remove(t);
        }
      }
    }

    // Convert orphaned forms, to animate them out
    Iterable<Key> placedKeys =
        placedSurfaces.values.map((SurfaceForm f) => f.key);
    _orphanedForms.removeWhere((SurfaceForm f) => placedKeys.contains(f.key));
    for (Surface s in _prevForms.keys) {
      _orphanedForms.add(_orphanedForm(s, _prevForms[s], offscreen));
    }
    _prevForms
      ..clear()
      ..addAll(placedSurfaces);

    /// Create form forest
    final Forest<SurfaceForm> formForest =
        dependentSpanningTrees.mapForest((Surface s) => placedSurfaces[s]);
    for (SurfaceForm orphan in _orphanedForms) {
      formForest.add(new Tree<SurfaceForm>(value: orphan));
    }

    return new SurfaceStage(forms: formForest);
  }
}
