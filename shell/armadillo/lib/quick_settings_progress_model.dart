// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// Spring description used by the minimization and quick settings reveal
/// simulations.
const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 600.0, friction: 50.0);

/// Keeps track of quick settings opening progress.
class QuickSettingsProgressModel extends SpringModel {
  /// Constructor.
  QuickSettingsProgressModel() : super(springDescription: _kSimulationDesc);

  /// Shows quick settings.
  void show() {
    target = 1.0;
  }

  /// Hides quick settings.
  void hide() {
    target = 0.0;
  }

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static QuickSettingsProgressModel of(BuildContext context) =>
      new ModelFinder<QuickSettingsProgressModel>().of(context);
}
