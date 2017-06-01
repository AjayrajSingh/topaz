// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import 'model.dart';
import 'sized_surface.dart';
import 'surface_widget.dart';

//ignore: unused_element
void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Callback to be called when a drag of this starts
typedef void DependentSimulatedDragStartCallback(
    Surface surface, SimulatedDragStartDetails details);

/// Callback to be called when a drag of this ends
typedef void DependentSimulatedDragEndCallback(
    Surface surface, Rect rect, SimulatedDragEndDetails details);

/// A Widget that lays out Surface pairs with Dependency-Copresent relationship,
/// so they respond correctly to surface navigation gestures
class DependentSimulatedPositioned extends StatelessWidget {
  /// The ordered list of dependent surfaces to be laid out
  final List<SizedSurface> surfaces;

  /// Callback to be called when a drag of this starts, if not null.
  final DependentSimulatedDragStartCallback onDragStart;

  /// Callback to be called when a drag of this ends, if not null.
  final DependentSimulatedDragEndCallback onDragEnd;

  /// Constructor
  DependentSimulatedPositioned({
    Key key,
    @required this.surfaces,
    this.onDragStart,
    this.onDragEnd,
  })
      : super(key: key) {
    assert(surfaces?.isNotEmpty ?? false);
  }

  Widget _widgetize(Surface surface) => new ScopedModel<Surface>(
        model: surface,
        child: new SurfaceWidget(),
      );

  @override
  Widget build(BuildContext context) {
    SizedSurface sizedSurface = surfaces.elementAt(0);
    Widget childWidget = _widgetize(sizedSurface.surface);
    Rect screenRect = Offset.zero & MediaQuery.of(context).size;
    if (surfaces.length == 1) {
      return new SimulatedPositioned(
        key: new GlobalObjectKey(sizedSurface.surface),
        rect: sizedSurface.rect,
        child: childWidget,
        onDragStart: (SimulatedDragStartDetails details) {
          onDragStart?.call(sizedSurface.surface, details);
        },
        onDragEnd: (SimulatedDragEndDetails details) {
          onDragEnd?.call(sizedSurface.surface, null, details);
        },
      );
    } else {
      return new SimulatedPositioned(
        key: new GlobalObjectKey(sizedSurface.surface),
        rect: screenRect,
        child: new Stack(
          children: <Widget>[
            new Positioned.fromRect(
              rect: sizedSurface.rect,
              child: childWidget,
            ),
            new DependentSimulatedPositioned(
              surfaces: surfaces.sublist(1),
              onDragStart: onDragStart,
              onDragEnd: onDragEnd,
            )
          ],
        ),
        onDragStart: (SimulatedDragStartDetails details) {
          onDragStart(sizedSurface.surface, details);
        },
        onDragEnd: (SimulatedDragEndDetails details) {
          onDragEnd(sizedSurface.surface, null, details);
        },
        dragOffsetTransform: sizedSurface.surface.canDismiss()
            ? null
            : (Offset currentOffset, DragUpdateDetails details) {
                double scale = max(1.0, currentOffset.distanceSquared / 100.0);
                return details.delta / scale;
              },
      );
    }
  }
}
