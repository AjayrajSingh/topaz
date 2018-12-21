// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:ui' show VoidCallback;

import 'package:fidl_fuchsia_cobalt/fidl_async.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'overlay_drag_model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 450.0, friction: 50.0);

/// Model controlling an overlay.
class OverlayPositionModel extends TracingSpringModel {
  final String traceName;
  final Duration noInteractionTimeout;

  OverlayDragModel _overlayDragModel;
  Timer _noInteractionTimer;
  VoidCallback onHide;
  VoidCallback onNoInteraction;

  /// Constructor.
  OverlayPositionModel({
    Logger logger,
    this.traceName,
    int showMetricId,
    int hideMetricId,
    this.noInteractionTimeout = const Duration(seconds: 20),
  }) : super(
          springDescription: _kSimulationDesc,
          traceName: traceName,
          cobaltLogger: logger,
          targetToCobaltMetricIdMap: <double, int>{
            1.0: showMetricId,
            0.0: hideMetricId
          },
        ) {
    _overlayDragModel = new OverlayDragModel(overlayPositionModel: this)
      ..addListener(notifyListeners);
  }

  OverlayDragModel get overlayDragModel => _overlayDragModel;

  /// Shows the overlay.
  void show() {
    if (target != 1.0) {
      Timeline.instantSync('$traceName: show overlay');
      target = 1.0;

      restartNoInteractionTimer();
    }
  }

  /// Hides the overlay.
  void hide() {
    if (target != 0.0) {
      onHide?.call();
      Timeline.instantSync('$traceName: hide overlay');
      target = 0.0;

      _stopNoInteractionTimer();
    }
  }

  /// Resets the no interaction timer.
  void restartNoInteractionTimer() {
    _stopNoInteractionTimer();
    if (noInteractionTimeout != null) {
      _noInteractionTimer = new Timer(noInteractionTimeout, () {
        onNoInteraction?.call();
        hide();
      });
    }
  }

  void _stopNoInteractionTimer() {
    _noInteractionTimer?.cancel();
  }
}
