// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import 'overlay_position_model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const RK4SpringDescription _kSimulationDesc =
    RK4SpringDescription(tension: 450.0, friction: 50.0);

/// Tracks any ongoing vertical drag that effects the overlay.
class OverlayDragModel extends TickingModel {
  /// The overlay position model.
  final OverlayPositionModel overlayPositionModel;

  final double flingMinPixelsPerSecond;
  final double resetDistance;

  /// The current vertical drag offset.
  double offset = 0.0;

  RK4SpringSimulation _resetSimulation;

  /// Constructor.
  OverlayDragModel({
    @required this.overlayPositionModel,
    this.flingMinPixelsPerSecond = 100.0,
    this.resetDistance = -32.0,
  });

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static OverlayDragModel of(BuildContext context) =>
      ModelFinder<OverlayDragModel>().of(context);

  /// Called when a vertical drag starts.
  void start() {}

  /// Called when a vertical drag updates.
  void update({@required double delta}) {
    if (delta == 0.0) {
      return;
    }
    offset += delta;
    notifyListeners();
  }

  /// Called when a vertical drag ends.
  void end({@required double verticalPixelsPerSecond}) {
    /// If offset greater than threshold or velocity is a fling downward, reset.
    /// Otherwise fill.
    if (overlayPositionModel.value == 0.0) {
      if (offset <= resetDistance ||
          verticalPixelsPerSecond <= -flingMinPixelsPerSecond) {
        overlayPositionModel.show();
      }
    } else {
      if (offset >= -resetDistance ||
          verticalPixelsPerSecond >= flingMinPixelsPerSecond) {
        overlayPositionModel.hide();
      }
    }

    /// Spring offset to 0.0.  Set effectedModel to null when 0.0.
    _resetSimulation = RK4SpringSimulation(
      initValue: offset,
      desc: _kSimulationDesc,
    )..target = 0.0;
    startTicking();
  }

  @override
  bool handleTick(double elapsedSeconds) {
    if (_resetSimulation == null) {
      return false;
    }

    if (!_resetSimulation.isDone) {
      _resetSimulation.elapseTime(elapsedSeconds);
    }

    if (!_resetSimulation.isDone) {
      offset = _resetSimulation.value;
      return true;
    }

    _resetSimulation = null;
    offset = 0.0;
    return false;
  }
}
