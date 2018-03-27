// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.logging/logging.dart';

import '../widgets/rk4_spring_simulation.dart';
import 'spring_model.dart';

export 'spring_model.dart' show ScopedModel, Model, ScopedModelDescendant;

const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 450.0, friction: 50.0);

/// Models the progress of a spring simulation.
class TracingSpringModel extends SpringModel {
  final FrameRateTracer _frameRateTracer;

  /// Constructor.
  TracingSpringModel({
    RK4SpringDescription springDescription: _kSimulationDesc,
    String traceName: 'TracingSpringModel',
  })  : _frameRateTracer = new FrameRateTracer(name: traceName),
        super(springDescription: springDescription);

  @override
  set target(double target) {
    _frameRateTracer.start(targetName: '$target');
    super.target = target;
  }

  @override
  bool handleTick(double elapsedSeconds) {
    _frameRateTracer.tick();
    bool result = super.handleTick(elapsedSeconds);
    if (isDone) {
      _frameRateTracer.done();
    }
    return result;
  }
}
