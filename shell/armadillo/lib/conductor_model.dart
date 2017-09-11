// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

import 'idle_mode_builder.dart';
import 'now_builder.dart';
import 'recents_builder.dart';

/// Provides builders for Conductor.
class ConductorModel extends Model {
  final IdleModeBuilder _idleModeBuilder = new IdleModeBuilder();
  final NowBuilder _nowBuilder = new NowBuilder();
  final RecentsBuilder _recentsBuilder = new RecentsBuilder();

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static ConductorModel of(BuildContext context) =>
      new ModelFinder<ConductorModel>().of(context);

  /// Builds the idle mode.
  IdleModeBuilder get idleModeBuilder => _idleModeBuilder;

  /// Builds now.
  NowBuilder get nowBuilder => _nowBuilder;

  /// Builds recents.
  RecentsBuilder get recentsBuilder => _recentsBuilder;
}
