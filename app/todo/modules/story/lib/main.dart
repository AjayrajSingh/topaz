// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'src/module_model.dart';
import 'src/screen.dart';

void main() {
  ModuleWidget<StoryModuleModel> moduleWidget =
      new ModuleWidget<StoryModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new StoryModuleModel(),
    child: const StoryScreen(),
  )..advertise();

  runApp(moduleWidget);
}
