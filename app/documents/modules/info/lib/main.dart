// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/info_module_model.dart';
import 'src/widgets/info.dart';

void main() {
  setupLogger();

  ApplicationContext appContext = new ApplicationContext.fromStartupInfo();

  ModuleWidget<InfoModuleModel> moduleWidget =
      new ModuleWidget<InfoModuleModel>(
    moduleModel: new InfoModuleModel(),
    applicationContext: appContext,
    child: const Info(),
  )..advertise();

  runApp(moduleWidget);
}
