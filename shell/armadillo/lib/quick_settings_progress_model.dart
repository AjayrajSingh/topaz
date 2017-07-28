// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// Keeps track of quick settings opening progress.
class QuickSettingsProgressModel extends Model {
  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static QuickSettingsProgressModel of(BuildContext context) =>
      new ModelFinder<QuickSettingsProgressModel>().of(context);

  // These are animation values, updated by the Now widget through the two
  // listeners below
  double _quickSettingsProgress = 0.0;

  /// Updates the progress of quick settings being shown.
  set quickSettingsProgress(double quickSettingsProgress) {
    if (quickSettingsProgress != _quickSettingsProgress) {
      _quickSettingsProgress = quickSettingsProgress;
      notifyListeners();
    }
  }

  /// The current progress of the quick settings animation.
  double get quickSettingsProgress => _quickSettingsProgress;
}
