// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// DragStartDetails with drag Offset
class SimulatedDragStartDetails extends DragStartDetails {
  /// Construct a SimulatedDragStartDetails
  SimulatedDragStartDetails({Offset globalPosition})
      : super(globalPosition: globalPosition);
}

/// DragEndDetails with drag Offset
class SimulatedDragEndDetails extends DragEndDetails {
  /// Construct a SimulatedDragEndDetails
  SimulatedDragEndDetails({
    Velocity velocity,
    double primaryVelocity,
    this.offset: Offset.zero,
  })
      : super(
          velocity: velocity,
          primaryVelocity: primaryVelocity,
        );

  /// The offset created by the drag.
  final Offset offset;
}

/// Callback to get SimulatedDragStartDetails onDragStart
typedef void SimulatedDragStartCallback(SimulatedDragStartDetails details);

/// Callback to get SimulatedDragEndDetails onDragEnd
typedef void SimulatedDragEndCallback(SimulatedDragEndDetails details);

/// An automatically animated widget that keeps stateful position and momentum.
///
/// Only works if it's the child of a [Stack].
class SimulatedPositioned extends StatefulWidget {
  /// Creates a widget that has stateful position and momentum, which can be
  /// modified directly by gesture, or animated by repositioning.
  SimulatedPositioned({
    Key key,
    @required this.rect,
    Rect initRect,
    @required this.child,
    this.draggable: true,
    this.onDragStart,
    this.onDragEnd,
  })
      : this.initRect = initRect ?? rect,
        super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// The child's rect.
  final Rect rect;

  /// The original position
  final Rect initRect;

  /// If true the SimulatedPositioned can be manipulated directly via touch
  final bool draggable;

  /// Callback called when a drag of this ends, if not null.
  final SimulatedDragStartCallback onDragStart;

  /// Callback called when a drag of this ends, if not null.
  final SimulatedDragEndCallback onDragEnd;

  @override
  State<SimulatedPositioned> createState() => new _SimulatedPositionedState();

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('child: $child');
    description.add('rect: $rect');
    description.add('initRect: $initRect');
  }
}

class _SimulatedPositionedState extends State<SimulatedPositioned>
    with TickerProviderStateMixin {
  _SimAnimationController _positionAnimation;
  _SimAnimationController _sizeAnimation;
  Offset _offset;

  @override
  void initState() {
    super.initState();
    _positionAnimation = new _SimAnimationController(
      vsync: this,
      position: widget.initRect.center,
    );
    _sizeAnimation = new _SimAnimationController(
      vsync: this,
      position: widget.initRect.size.bottomRight(Offset.zero),
    );
    _setTarget();
  }

  @override
  void didUpdateWidget(SimulatedPositioned oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setTarget();
  }

  @override
  void dispose() {
    _positionAnimation.dispose();
    _sizeAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new AnimatedBuilder(
      child: widget.draggable
          ? new GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _startDrag,
              onPanUpdate: _updateDrag,
              onPanEnd: _endDrag,
              child: widget.child,
            )
          : widget.child,
      animation: new Listenable.merge(<Listenable>[
        _positionAnimation,
        _sizeAnimation,
      ]),
      builder: (BuildContext context, Widget child) {
        final Offset centerPos = _offset ?? _positionAnimation.value;
        final Size size = new Size(
          _sizeAnimation.value.dx,
          _sizeAnimation.value.dy,
        );
        return new Positioned(
          left: centerPos.dx - size.width / 2.0,
          top: centerPos.dy - size.height / 2.0,
          width: size.width,
          height: size.height,
          child: child,
        );
      },
    );
  }

  void _setTarget() {
    _positionAnimation.target = widget.rect.center;
    _sizeAnimation.target = widget.rect.size.bottomRight(Offset.zero);
  }

  void _startDrag(DragStartDetails details) {
    setState(() {
      _offset = _positionAnimation.value;
      _positionAnimation.stop(canceled: true);
      _sizeAnimation.stop();
      widget.onDragStart?.call(new SimulatedDragStartDetails(
        globalPosition: details.globalPosition,
      ));
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
    });
  }

  void _endDrag(DragEndDetails details) {
    setState(() {
      _positionAnimation.reset(_offset, details.velocity.pixelsPerSecond);
      _setTarget();
      widget.onDragEnd?.call(new SimulatedDragEndDetails(
        velocity: details.velocity,
        primaryVelocity: details.primaryVelocity,
        offset: _offset - widget.rect.center,
      ));
      _offset = null;
    });
  }
}

const SpringDescription _kSimSpringDescription = const SpringDescription(
  mass: 1.0,
  springConstant: 120.0,
  damping: 19.0,
);

class _SimAnimationController extends Animation<Offset>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  _SimAnimationController({
    Offset target,
    Offset position: Offset.zero,
    Offset velocity: Offset.zero,
    @required TickerProvider vsync,
  })
      : _status = AnimationStatus.forward {
    assert(vsync != null);
    assert(position != null);
    assert(velocity != null);
    _ticker = vsync.createTicker(_tick);
    reset(position, velocity);
    if (target != null) {
      this.target = target;
    }
  }

  Ticker _ticker;
  Offset _target;
  Simulation _xSimulation;
  Simulation _ySimulation;

  Offset get target => _target;
  set target(Offset value) {
    assert(value != null);
    _ticker.stop(canceled: true);
    _target = value;
    _xSimulation = new SpringSimulation(
      _kSimSpringDescription,
      _value.dx,
      _target.dx,
      _velocity.dx,
    );
    _ySimulation = new SpringSimulation(
      _kSimSpringDescription,
      _value.dy,
      _target.dy,
      _velocity.dy,
    );
    _ticker.start();
  }

  void reset(Offset position, Offset velocity) {
    assert(position != null);
    assert(velocity != null);
    _ticker.stop(canceled: true);
    _value = position;
    _velocity = velocity;
  }

  @override
  AnimationStatus get status => _status;
  AnimationStatus _status;

  /// The current value of the animation.
  @override
  Offset get value => _value;
  Offset _value;

  Offset get velocity => _velocity;
  Offset _velocity;

  void stop({bool canceled: true}) {
    _ticker.stop(canceled: canceled);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    Duration lastElapsedDuration = elapsed;
    final double elapsedInSeconds =
        lastElapsedDuration.inMicroseconds.toDouble() /
            Duration.MICROSECONDS_PER_SECOND;
    _value = new Offset(
      _xSimulation.x(elapsedInSeconds),
      _ySimulation.x(elapsedInSeconds),
    );
    _velocity = new Offset(
      _xSimulation.dx(elapsedInSeconds),
      _ySimulation.dx(elapsedInSeconds),
    );
    if (_xSimulation.isDone(elapsedInSeconds) &&
        _ySimulation.isDone(elapsedInSeconds)) {
      _status = AnimationStatus.completed;
      stop(canceled: false);
    }
    notifyListeners();
    _checkStatusChanged();
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    final AnimationStatus newStatus = status;
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      notifyStatusListeners(newStatus);
    }
  }
}
