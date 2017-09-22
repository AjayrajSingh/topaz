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

/// Retruns a Simulation with start, velocity initial values and a target of end
/// It is either moving forward or complete, but has no specified duration.
typedef Simulation SimulationBuilder(double start, double velocity, double end);

/// Status that map to forward for SimulatedAnimation
const List<AnimationStatus> _kMovingStatus = const <AnimationStatus>[
  AnimationStatus.forward,
  AnimationStatus.reverse
];

/// Animation powered by a simulation, which can be reset, started, and stopped.
abstract class SimulatedAnimation<T, S> extends Animation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationLazyListenerMixin {
  /// Create a simulated animation
  SimulatedAnimation({
    @required this.vsync,
    @required T value,
    @required S state,
  })
      : _value = value,
        _state = state;

  /// The ticker provider for this SimulatedAnimation
  final TickerProvider vsync;
  Ticker _ticker;

  @override
  AnimationStatus get status => _ticker != null && _ticker.isActive
      ? AnimationStatus.forward
      : AnimationStatus.completed;

  /// The current target of this simulation
  T get target;

  /// The current value of this animation
  @override
  T get value => _value;
  T _value;
  set value(T value) {
    assert(value != null);
    stop();
    _value = value;
    notifyListeners();
  }

  /// The encapulated state of the simulation
  S get state => _state;
  S _state;

  /// Start the simulation from its current state
  @mustCallSuper
  void start({S initState}) {
    _ticker ??= vsync.createTicker(tick);
    if (_ticker.isActive) {
      return;
    }
    _state = initState ?? _state;
    onStart();
    _ticker.start().whenComplete(onComplete);
  }

  /// Stop the simulation
  @mustCallSuper
  void stop() {
    if (_ticker != null && _ticker.isActive) {
      _ticker?.stop(canceled: true);
      onStop();
      notifyListeners();
    }
  }

  /// Process a tick of the ticker
  @protected
  void tick(Duration elapsed);

  /// Called when this animation is started
  @protected
  void onStart() {}

  /// Called when this animation is stopped
  @protected
  void onStop() {}

  /// Called when this animation is complete
  @protected
  void onComplete() {
    notifyStatusListeners(AnimationStatus.completed);
  }

  @override
  void didStartListening() {}

  @override
  void didStopListening() {
    _ticker.dispose();
    _ticker = null;
  }
}

/// SimulatedAnimation for two dimensions.
class Sim2DAnimation extends SimulatedAnimation<Offset, Offset> {
  /// Construct basic Sim2DAnimation
  Sim2DAnimation({
    @required TickerProvider vsync,
    @required this.xSim,
    @required this.ySim,
    @required Offset target,
  })
      : _target = target,
        super(vsync: vsync, value: target, state: Offset.zero);

  /// Construct Sim2DAnimation which targets to a reference Sim2DAnimation.
  factory Sim2DAnimation.withMovingTarget({
    @required TickerProvider vsync,
    @required SimulationBuilder xSim,
    @required SimulationBuilder ySim,
    @required Animation<Offset> target,
    Offset offset,
    bool sticky,
  }) =>
      new _Sim2DAnimationWithMovingTarget(
        vsync: vsync,
        xSim: xSim,
        ySim: ySim,
        targetAnimation: target,
        offset: offset ?? Offset.zero,
        sticky: sticky ?? false,
      );

  /// The x dimension simulation builder function
  final SimulationBuilder xSim;

  /// The y dimension simulation builder function
  final SimulationBuilder ySim;

  Simulation _x;
  Simulation _y;

  @override
  Offset get target => _target;
  Offset _target;

  @override
  void onStart() {
    super.onStart();
    _x = xSim(_value.dx, _state.dx, target.dx);
    _y = ySim(_value.dy, _state.dy, target.dy);
  }

  @override
  void tick(Duration elapsed) {
    final double elapsedInSeconds =
        elapsed.inMicroseconds.toDouble() / Duration.MICROSECONDS_PER_SECOND;
    _value = new Offset(_x.x(elapsedInSeconds), _y.x(elapsedInSeconds));
    _state = new Offset(_x.dx(elapsedInSeconds), _y.dx(elapsedInSeconds));
    notifyListeners();
    if (_x.isDone(elapsedInSeconds) && _y.isDone(elapsedInSeconds)) {
      _ticker.stop();
    }
  }

  @override
  String toString() => 'Sim2DAnimation('
      'value: $value, velocity: $state, target: $target, status: $status)';
}

class _Sim2DAnimationWithMovingTarget extends Sim2DAnimation {
  _Sim2DAnimationWithMovingTarget({
    @required TickerProvider vsync,
    @required SimulationBuilder xSim,
    @required SimulationBuilder ySim,
    @required this.targetAnimation,
    @required this.offset,
    @required this.sticky,
  })
      : super(vsync: vsync, xSim: xSim, ySim: ySim, target: Offset.zero) {
    targetAnimation.addListener(_update);
  }

  final Animation<Offset> targetAnimation;
  final Offset offset;
  final bool sticky;
  bool running = true;

  @override
  AnimationStatus get status => super.status == AnimationStatus.forward ||
          _kMovingStatus.contains(targetAnimation.status)
      ? AnimationStatus.forward
      : AnimationStatus.completed;

  @override
  Offset get target => targetAnimation.value + offset;

  void _update() {
    if (super.status == AnimationStatus.forward) {
      // In the middle of animation so just update the simulations
      _x = xSim(_value.dx, _state.dx, target.dx);
      _y = ySim(_value.dy, _state.dy, target.dy);
    } else if (running) {
      // Not currently animating
      if (sticky) {
        _value = targetAnimation.value + offset;
        _state = Offset.zero;
      } else {
        start();
      }
    }
  }

  @override
  void onStart() {
    super.onStart();
    running = true;
  }

  @override
  void onStop() {
    super.onStop();
    running = false;
  }

  @override
  void didStopListening() {
    super.didStopListening();
    targetAnimation.removeListener(_update);
  }
}

/// A delegate for CustomSingleChildLayout that positions its child centered at
/// the positionAnimation.value offset, and with the sizeAnimation.value size.
class PositionedLayoutDelegate extends SingleChildLayoutDelegate {
  /// Constructor
  PositionedLayoutDelegate({
    @required this.positionAnimation,
    @required this.sizeAnimation,
  })
      : super(
          relayout: new Listenable.merge(<Listenable>[
            positionAnimation,
            sizeAnimation,
          ]),
        );

  /// The animation for the center position
  final Animation<Offset> positionAnimation;

  /// The animation for the size
  final Animation<Offset> sizeAnimation;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      new BoxConstraints.tightFor(
          width: sizeAnimation.value.dx, height: sizeAnimation.value.dy);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      positionAnimation.value - childSize.center(Offset.zero);

  @override
  bool shouldRelayout(PositionedLayoutDelegate old) =>
      old.positionAnimation != positionAnimation ||
      old.sizeAnimation != sizeAnimation;
}
