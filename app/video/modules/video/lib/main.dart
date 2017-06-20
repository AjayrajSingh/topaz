// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';
import 'src/widgets.dart';

void main() {
  setupLogger();

  ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
  ModuleWidget<VideoModuleModel> moduleWidget =
      new ModuleWidget<VideoModuleModel>(
    moduleModel: new VideoModuleModel(
      appContext: _appContext,
    ),
    applicationContext: _appContext,
    child: new VideoApp(),
  );
  moduleWidget.advertise();

  runApp(moduleWidget);
}
