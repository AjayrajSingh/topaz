// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';
import 'src/modular/screen.dart';

void main() {
  setupLogger();

  ModuleWidget<YoutubeStoryModuleModel> moduleWidget =
      new ModuleWidget<YoutubeStoryModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new YoutubeStoryModuleModel(),
    child: new YoutubeStoryScreen(),
  );

  moduleWidget.advertise();
  runApp(moduleWidget);
}
