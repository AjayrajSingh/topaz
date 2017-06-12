// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';

/// Main entry point to the color module.
void main() {
  ModuleWidget<ColorModuleModel> moduleWidget =
      new ModuleWidget<ColorModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new ColorModuleModel(),
    child: new ScopedModelDescendant<ColorModuleModel>(
      builder: (_, __, ColorModuleModel model) =>
          new Container(color: model.color),
    ),
  );

  moduleWidget.advertise();

  runApp(moduleWidget);
}
