// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';
import 'package:sysui_widgets/rk4_spring_simulation.dart';

import 'ticking_model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 250.0, friction: 50.0);

/// Base class for [Model]s that depend on a Ticker.
class StoryClusterEntranceTransitionModel extends TickingModel {
  RK4SpringSimulation _transitionSimulation;
  double _remainingDelay;

  /// [delay] is the time to delay the transition.
  StoryClusterEntranceTransitionModel({
    double delay: 0.0,
    bool completed: true,
  }) {
    reset(delay: delay, completed: completed);
  }

  /// Resets the simulation.
  void reset({double delay: 0.0, bool completed: true}) {
    _remainingDelay = completed ? 0.0 : delay;
    _transitionSimulation = new RK4SpringSimulation(
      initValue: completed ? 1.0 : 0.0,
      desc: _kSimulationDesc,
    );
    _transitionSimulation.target = 1.0;
    startTicking();
  }

  /// The progress of the story rearrangement scrim animation.
  double get progress => _transitionSimulation.value;

  @override
  bool handleTick(double elapsedSeconds) {
    double tickAmount = elapsedSeconds;
    if (_remainingDelay > 0.0) {
      if (elapsedSeconds > _remainingDelay) {
        _remainingDelay = 0.0;
        tickAmount = elapsedSeconds - _remainingDelay;
      } else {
        _remainingDelay -= elapsedSeconds;
        tickAmount = 0.0;
      }
    }
    _transitionSimulation.elapseTime(tickAmount);
    return !_transitionSimulation.isDone;
  }
}
