// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'flux.dart';
import 'sim.dart';
import 'surface_form.dart';
import 'surface_frame.dart';
import 'tree.dart';

const SpringDescription _kSimSpringDescription = const SpringDescription(
  mass: 1.0,
  stiffness: 220.0,
  damping: 29.0,
);

// Distance from left edge of surface where panning can be initiated.
const double _kPanStartXOffset = 32.0;

/// Stages determine how things move, and how they can be manipulated
class SurfaceStage extends StatelessWidget {
  /// Construct a SurfaceStage with these forms
  const SurfaceStage({@required this.forms});

  /// The forms inside this stage
  final Forest<SurfaceForm> forms;

  @override
  Widget build(BuildContext context) => new Stack(
      fit: StackFit.expand,
      children: forms
          .reduceForest((SurfaceForm f, Iterable<_SurfaceInstance> children) =>
              new _SurfaceInstance(form: f, dependents: children.toList()))
          .toList()
            ..sort((_SurfaceInstance a, _SurfaceInstance b) =>
                b.form.depth.compareTo(a.form.depth)));
}

/// Instantiation of a Surface in SurfaceStage
class _SurfaceInstance extends StatefulWidget {
  /// SurfaceLayout
  _SurfaceInstance({
    @required this.form,
    this.dependents = const <_SurfaceInstance>[],
  }) : super(key: form.key);

  /// The form of this Surface
  final SurfaceForm form;

  /// Dependent surfaces
  final List<_SurfaceInstance> dependents;

  @override
  _SurfaceInstanceState createState() => new _SurfaceInstanceState();
}

class _SurfaceInstanceState extends State<_SurfaceInstance>
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
  void didUpdateWidget(_SurfaceInstance oldWidget) {
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

  // Returns true if panning was initiated [_kPanStartXOffset] from left edge.
  bool _panning = false;

  @override
  Widget build(BuildContext context) {
    Size parentSize = MediaQuery.of(context).size;
    final SurfaceForm form = widget.form;
    return new Stack(
      fit: StackFit.expand,
      children: <Widget>[
        new CustomSingleChildLayout(
          delegate: new PositionedLayoutDelegate(animation: animation),
          child: new GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails details) {
              Offset diff = details.globalPosition -
                  _toAbsolute(
                    form.position.topLeft,
                    parentSize,
                  );
              if (diff.dx < _kPanStartXOffset) {
                _panning = true;
              }
              _animation.update(
                value: animation.value,
                velocity: Rect.zero,
              );
              form.onDragStarted();
            },
            onPanUpdate: (DragUpdateDetails details) {
              if (!_panning) {
                return;
              }
              _animation.update(
                value: animation.value.shift(
                  _toFractional(
                    form.dragFriction(
                      _toAbsolute(
                        animation.value.center - form.position.center,
                        parentSize,
                      ),
                      details.delta,
                    ),
                    parentSize,
                  ),
                ),
                velocity: Rect.zero,
              );
            },
            onPanEnd: (DragEndDetails details) {
              if (!_panning) {
                return;
              }
              _panning = false;
              _animation
                ..update(
                  value: animation.value,
                  velocity: Rect.zero.shift(
                    _toFractional(
                      form.dragFriction(
                        _toAbsolute(
                          animation.value.center - form.position.center,
                          parentSize,
                        ),
                        details.velocity.pixelsPerSecond,
                      ),
                      parentSize,
                    ),
                  ),
                )
                ..done();
              form.onDragFinished(
                _toAbsolute(
                  animation.value.center - form.position.center,
                  parentSize,
                ),
                details.velocity,
              );
            },
            child: new SurfaceFrame(
              child: form.parts.keys.first,
              depth: form.depth,
              // HACK(alangardner): May need explicit interactable parameter
              interactable: form.dragFriction != kDragFrictionInfinite,
            ),
          ),
        ),
      ]..addAll(widget.dependents),
    );
  }

  Offset _toFractional(Offset absoluteOffset, Size size) {
    return new Offset(
      absoluteOffset.dx / size.width,
      absoluteOffset.dy / size.height,
    );
  }

  Offset _toAbsolute(Offset fractionalOffset, Size size) {
    return new Offset(
      fractionalOffset.dx * size.width,
      fractionalOffset.dy * size.height,
    );
  }
}

/// A delegate for CustomSingleChildLayout that positions its child centered at
/// the positionAnimation.value offset, and with the sizeAnimation.value size.
class PositionedLayoutDelegate extends SingleChildLayoutDelegate {
  /// Constructor
  PositionedLayoutDelegate({
    @required this.animation,
  }) : super(relayout: animation);

  /// The animation for the center position
  final Animation<Rect> animation;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      new BoxConstraints.tightFor(
        width: animation.value.size.width * constraints.maxWidth,
        height: animation.value.size.height * constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    Offset fractionalOffset =
        (animation.value.center - animation.value.size.center(Offset.zero));
    return new Offset(
      size.width * fractionalOffset.dx,
      size.height * fractionalOffset.dy,
    );
  }

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
