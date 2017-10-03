// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'flux.dart';
import 'sim.dart';
import 'surface_form.dart';
import 'surface_frame.dart';

const SpringDescription _kSimSpringDescription = const SpringDescription(
  mass: 1.0,
  stiffness: 220.0,
  damping: 29.0,
);

/// Instantiation of a Surface in SurfaceSpace
class SurfaceInstance extends StatefulWidget {
  /// SurfaceLayout
  SurfaceInstance({
    @required this.form,
    this.dependents: const <SurfaceInstance>[],
  })
      : super(key: form.key);

  /// The form of this Surface
  final SurfaceForm form;

  /// Dependent surfaces
  final List<SurfaceInstance> dependents;

  @override
  _SurfaceInstanceState createState() => new _SurfaceInstanceState();
}

class _SurfaceInstanceState extends State<SurfaceInstance>
    with TickerProviderStateMixin {
  FluxAnimation<Rect> get animation => _animation;
  ManualAnimation<Rect> _animation;

  @override
  void initState() {
    super.initState();
    //TODO:(alangardner): figure out elevation layering
    _animation = new ManualAnimation<Rect>(
      value: widget.form.initPosition,
      velocity: Rect.zero,
      builder: (Rect value, Rect velocity) => new MovingTargetAnimation<Rect>(
              vsync: this,
              simulate: _kFormSimulate,
              target: _target,
              value: value,
              velocity: velocity)
          .stickyAnimation,
    )..done();
  }

  @override
  void didUpdateWidget(SurfaceInstance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation
      ..update(value: _animation.value, velocity: _animation.velocity)
      ..done();
  }

  FluxAnimation<Rect> get _target {
    final SurfaceForm f = widget.form;
    final _SurfaceInstanceState parentSurfaceState =
        context.ancestorStateOfType(const TypeMatcher<_SurfaceInstanceState>());
    return parentSurfaceState == null
        ? new ManualAnimation<Rect>(value: f.position, velocity: Rect.zero)
        : new TransformedAnimation<Rect>(
            animation: parentSurfaceState.animation,
            valueTransform: (Rect r) => f.position.shift(
                r.center - parentSurfaceState.widget.form.position.center),
            velocityTransform: (Rect r) => r,
          );
  }

  @override
  Widget build(BuildContext context) {
    final SurfaceForm form = widget.form;
    return new Stack(
        fit: StackFit.expand,
        children: <Widget>[
          new CustomSingleChildLayout(
            delegate: new PositionedLayoutDelegate(animation: animation),
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (DragStartDetails details) {
                _animation.update(value: animation.value, velocity: Rect.zero);
                form.onDragStarted();
              },
              onPanUpdate: (DragUpdateDetails details) {
                _animation.update(
                    value: animation.value.shift(form.dragFriction(
                        animation.value.center - form.position.center,
                        details.delta)),
                    velocity: Rect.zero);
              },
              onPanEnd: (DragEndDetails details) {
                form.onDragFinished(
                    animation.value.center - form.position.center,
                    details.velocity);
                _animation
                  ..update(
                      value: animation.value,
                      velocity: Rect.zero.shift(form.dragFriction(
                          animation.value.center - form.position.center,
                          details.velocity.pixelsPerSecond)))
                  ..done();
              },
              child: new SurfaceFrame(
                child: form.parts.keys.first,
                depth: form.depth,
              ),
            ),
          ),
        ]..addAll(widget.dependents));
  }
}

/// A delegate for CustomSingleChildLayout that positions its child centered at
/// the positionAnimation.value offset, and with the sizeAnimation.value size.
class PositionedLayoutDelegate extends SingleChildLayoutDelegate {
  /// Constructor
  PositionedLayoutDelegate({
    @required this.animation,
  })
      : super(relayout: animation);

  /// The animation for the center position
  final Animation<Rect> animation;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      new BoxConstraints.tightFor(
        width: animation.value.size.width,
        height: animation.value.size.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      animation.value.center - childSize.center(Offset.zero);

  @override
  bool shouldRelayout(PositionedLayoutDelegate old) =>
      old.animation.value != animation.value;
}

const double _kEpsilon = 1e-2;
const Tolerance _kTolerance = const Tolerance(
  distance: _kEpsilon,
  time: _kEpsilon,
  velocity: _kEpsilon,
);

Sim<Rect> _kFormSimulate(Rect value, Rect target, Rect velocity) =>
    new IndependentRectSim(
      positionSim: new Independent2DSim(
        xSim: new SpringSimulation(
          _kSimSpringDescription,
          value.center.dx,
          target.center.dx,
          velocity.center.dx,
          tolerance: _kTolerance,
        ),
        ySim: new SpringSimulation(
          _kSimSpringDescription,
          value.center.dy,
          target.center.dy,
          velocity.center.dy,
          tolerance: _kTolerance,
        ),
      ),
      sizeSim: new Independent2DSim(
        xSim: new SpringSimulation(
          _kSimSpringDescription,
          value.size.width,
          target.size.width,
          velocity.size.width,
          tolerance: _kTolerance,
        ),
        ySim: new SpringSimulation(
          _kSimSpringDescription,
          value.size.height,
          target.size.height,
          velocity.size.height,
          tolerance: _kTolerance,
        ),
      ),
    );
