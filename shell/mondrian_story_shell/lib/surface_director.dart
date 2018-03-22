// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'child_view.dart';
import 'container_layout.dart' as container;
import 'copresent_layout.dart' as copresent;
import 'inset_manager.dart';
import 'layout_model.dart';
import 'model.dart';
import 'pattern_layout.dart' as pattern;
import 'positioned_surface.dart';
import 'surface_form.dart';
import 'surface_stage.dart';
import 'tree.dart';

/// Directs the layout of the SurfaceSpace
class SurfaceDirector extends StatefulWidget {
  @override
  _SurfaceDirectorState createState() => new _SurfaceDirectorState();
}

class _SurfaceDirectorState extends State<SurfaceDirector> {
  final Map<Surface, SurfaceForm> _prevForms = <Surface, SurfaceForm>{};
  final List<Surface> _draggedSurfaces = <Surface>[];
  final List<SurfaceForm> _orphanedForms = <SurfaceForm>[];

  SurfaceForm _form(PositionedSurface ps, double depth, Offset offscreen) =>
      new SurfaceForm.single(
        key: new GlobalObjectKey(ps.surface),
        child: new ScopedModel<Surface>(
          model: ps.surface,
          child: new MondrianChildView(
            interactable: depth <= 0.0,
          ),
        ),
        position: ps.position,
        initPosition: ps.position.shift(offscreen),
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
          Surface surface, SurfaceForm form, Offset offscreen) =>
      new SurfaceForm.single(
        key: form.key,
        child: new ScopedModel<Surface>(
          model: surface,
          child: const MondrianChildView(
            interactable: false,
          ),
        ),
        position: form.position.shift(offscreen),
        initPosition: form.initPosition,
        depth: form.depth,
        friction: kDragFrictionInfinite,
        onPositioned: () {
          // TODO(alangardner): Callback to notify framework
          setState(() {
            _orphanedForms.removeWhere((SurfaceForm f) => (f.key == form.key));
          });
        },
      );

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.biggest.isInfinite || constraints.biggest.isEmpty) {
            return new Container();
          }
          final Offset offscreen = constraints.biggest.topRight(Offset.zero);
          return new SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: new ScopedModelDescendant<InsetManager>(
              builder: (
                BuildContext context,
                Widget child,
                InsetManager insetManager,
              ) {
                return new ScopedModelDescendant<LayoutModel>(
                  builder: (
                    BuildContext context,
                    Widget child,
                    LayoutModel layoutModel,
                  ) {
                    return new ScopedModelDescendant<SurfaceGraph>(
                      builder: (
                        BuildContext context,
                        Widget child,
                        SurfaceGraph graph,
                      ) {
                        return _buildStage(
                          context,
                          offscreen,
                          constraints,
                          insetManager,
                          layoutModel,
                          graph,
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      );

  Widget _buildStage(
    BuildContext context,
    Offset offscreen,
    BoxConstraints constraints,
    InsetManager insetManager,
    LayoutModel layoutModel,
    SurfaceGraph graph,
  ) {
    Map<Surface, SurfaceForm> placedSurfaces = <Surface, SurfaceForm>{};
    List<Surface> focusStack = graph.focusStack.toList();
    double depth = 0.0;
    // HACK(alangardner): Used to create illusion of symmetry
    BoxConstraints adjustedConstraints = new BoxConstraints(
      minWidth: constraints.minWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
      maxWidth: constraints.maxWidth - insetManager.value,
    );
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
            adjustedConstraints,
            focusStack,
            layoutModel,
          );
        } else if (last.properties.containerMembership != null &&
            last.properties.containerMembership.isNotEmpty) {
          positionedSurfaces = container.layoutSurfaces(
            context,
            adjustedConstraints,
            last,
            layoutModel,
          );
        } else {
          positionedSurfaces = copresent.layoutSurfaces(
            context,
            adjustedConstraints,
            focusStack,
            layoutModel,
          );
        }
      }
      for (PositionedSurface ps in positionedSurfaces) {
        if (!placedSurfaces.keys.contains(ps.surface)) {
          _prevForms.remove(ps.surface);
          placedSurfaces[ps.surface] = _form(ps, depth, offscreen);
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
