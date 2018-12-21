// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/entity.dart';
import 'package:fuchsia_modular/module.dart';

import 'bloc_provider.dart';

/// The [AppBloc] provides app level actions like launching other modules
class AppBloc implements BlocBase {
  final Entity shapeEntity;

  AppBloc(this.shapeEntity);

  void launchSquare() => Module().addModuleToStory(
      name: 'shape_module',
      intent: _makeIntent('com.fuchsia.shapes_mod.show_square'));

  void launchCircle() => Module().addModuleToStory(
      name: 'shape_module',
      intent: _makeIntent('com.fuchsia.shapes_mod.show_circle'));

  Intent _makeIntent(String action) => Intent(
        action: action,
        handler: 'shapes_mod',
      )..addParameterFromEntity('shape', shapeEntity);

  @override
  void dispose() {}
}
