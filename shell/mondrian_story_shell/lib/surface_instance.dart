// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'positioned_builder.dart';
import 'surface_form.dart';
import 'surface_frame.dart';

/// Instantiation of a Surface in SurfaceSpace
class SurfaceInstance extends StatefulWidget {
  /// SurfaceLayout
  SurfaceInstance({
    @required this.form,
    @required this.positionSim,
    @required this.sizeSim,
  })
      : super(key: form.key);

  /// The form of this Surface
  final SurfaceForm form;

  /// Position OffsetSimulation
  final Sim2DAnimation positionSim;

  /// TSize OffsetSimulation
  final Sim2DAnimation sizeSim;

  @override
  _SurfaceInstanceState createState() => new _SurfaceInstanceState();
}

class _SurfaceInstanceState extends State<SurfaceInstance> {
  Sim2DAnimation positionSim;
  Sim2DAnimation sizeSim;

  @override
  void initState() {
    super.initState();
    positionSim = widget.positionSim;
    positionSim.value = widget.form.initPosition.center;
    positionSim.start();
    sizeSim = widget.sizeSim;
    sizeSim.value = widget.form.position.size.bottomRight(Offset.zero);
    sizeSim.start();
  }

  @override
  void didUpdateWidget(SurfaceInstance oldWidget) {
    super.didUpdateWidget(oldWidget);
    Sim2DAnimation oldPositionSim = positionSim;
    Sim2DAnimation oldSizeSim = sizeSim;
    positionSim = widget.positionSim;
    positionSim.value = oldPositionSim.value;
    positionSim.start(initState: oldPositionSim.state);
    sizeSim = widget.sizeSim;
    sizeSim.value = oldSizeSim.value;
    sizeSim.start(initState: oldSizeSim.state);
  }

  @override
  Widget build(BuildContext context) {
    return new CustomSingleChildLayout(
      delegate: new PositionedLayoutDelegate(
        positionAnimation: positionSim,
        sizeAnimation: sizeSim,
      ),
      child: new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails details) {
          positionSim.stop();
          widget.form.onDragStarted();
        },
        onPanUpdate: (DragUpdateDetails details) {
          positionSim.stop();
          positionSim.value = positionSim.value +
              widget.form.dragFriction(
                  positionSim.value - widget.form.position.center,
                  details.delta);
        },
        onPanEnd: (DragEndDetails details) {
          widget.form.onDragFinished(
              positionSim.value - widget.form.position.center,
              details.velocity);
          positionSim.start(initState: details.velocity.pixelsPerSecond);
        },
        child: new SurfaceFrame(
          child: widget.form.parts.keys.first,
          depth: widget.form.depth,
        ),
      ),
    );
  }
}
