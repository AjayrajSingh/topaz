// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

/// Spring description used by the minimization and quick settings reveal
/// simulations.
const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 600.0, friction: 50.0);

/// Tracks the progress of now minimizing.
class NowMinimizationModel extends SpringModel {
  VoidCallback _onMinimize;
  VoidCallback _onMaximize;

  /// Constructor.
  NowMinimizationModel() : super(springDescription: _kSimulationDesc);

  /// Called when now is minimized.
  set onMinimize(VoidCallback onMinimize) {
    _onMinimize = onMinimize;
  }

  /// Called when now is maximized.
  set onMaximize(VoidCallback onMaximize) {
    _onMaximize = onMaximize;
  }

  /// Minimizes Now to its bar state.
  void minimize() {
    if (!_minimizing) {
      target = 1.0;
      _onMinimize?.call();
    }
  }

  /// Maximizes Now to display the user and context text.
  void maximize() {
    if (_minimizing) {
      target = 0.0;
      _onMaximize?.call();
    }
  }

  bool get _minimizing => target == 1.0;

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static NowMinimizationModel of(BuildContext context) =>
      new ModelFinder<NowMinimizationModel>().of(context);
}
