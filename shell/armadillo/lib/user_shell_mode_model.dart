// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// States that the user shell can be in
enum UserShellMode {
  /// Ready for interaction with low information density and minimal visual
  /// noise
  ambient,

  /// The most minimal state
  idle,

  /// Standard interaction mode
  normal,
}

/// Holds information regarding whether the user shell is the normal, ambient or
/// idle state.
///
/// Defaults to normal
class UserShellModeModel extends Model {
  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static UserShellModeModel of(BuildContext context) =>
      new ModelFinder<UserShellModeModel>().of(context);

  UserShellMode _mode = UserShellMode.normal;

  /// The current [UserShellMode] of the user shell
  UserShellMode get mode => _mode;

  set mode(UserShellMode mode) {
    _mode = mode;
    notifyListeners();
  }
}
