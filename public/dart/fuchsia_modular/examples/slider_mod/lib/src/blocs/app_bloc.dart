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

  void launchSquare() =>
      _launchModule('shape_module', 'com.fuchsia.shapes_mod.show_square');

  void launchCircle() =>
      _launchModule('shape_module', 'com.fuchsia.shapes_mod.show_circle');

  void _launchModule(String name, String action) {
    _makeIntent(action).then(
        (intent) => Module().addModuleToStory(name: name, intent: intent));
  }

  Future<Intent> _makeIntent(String action) async => Intent(
        action: action,
        handler: 'fuchsia-pkg://fuchsia.com/shapes_mod#meta/shapes_mod.cmx',
      )..addParameterFromEntityReference(
          'shape', await shapeEntity.getEntityReference());

  @override
  void dispose() {}
}
