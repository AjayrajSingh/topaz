// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../widgets/rk4_spring_simulation.dart';
import 'ticking_model.dart';

export 'model.dart' show ScopedModel, Model, ScopedModelDescendant;

const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 250.0, friction: 50.0);
const Duration _kIdleModeTimeout = const Duration(seconds: 60);

/// Handles transitioning into Idle mode.
class IdleModel extends TickingModel {
  final RK4SpringSimulation _transitionSimulation = new RK4SpringSimulation(
    initValue: 0.0,
    desc: _kSimulationDesc,
  );

  Timer _userInteractionTimer;
  bool _isIdle = false;

  /// Constructor.
  IdleModel() {
    _userInteractionTimer = new Timer(
      _kIdleModeTimeout,
      _enterIdleMode,
    );
  }

  /// Adjusts idle mode based on the user interaction.
  void onUserInteraction() {
    _leaveIdleMode();
    _userInteractionTimer?.cancel();
    _userInteractionTimer = new Timer(
      _kIdleModeTimeout,
      _enterIdleMode,
    );
  }

  void _enterIdleMode() {
    if (_transitionSimulation.target != 1.0) {
      _transitionSimulation.target = 1.0;
      startTicking();
    }
    if (!_isIdle) {
      _isIdle = true;
      notifyListeners();
    }
  }

  void _leaveIdleMode() {
    if (_transitionSimulation.target != 0.0) {
      _transitionSimulation.target = 0.0;
      startTicking();
    }
    if (_isIdle) {
      _isIdle = false;
      notifyListeners();
    }
  }

  /// The progress of the idle animation.
  double get progress => _transitionSimulation.value;

  /// Returns true if we are in idle mode.
  bool get isIdle => _isIdle;

  @override
  bool handleTick(double elapsedSeconds) {
    _transitionSimulation.elapseTime(elapsedSeconds);
    return !_transitionSimulation.isDone;
  }
}
