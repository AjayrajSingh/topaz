// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';
import 'src/screen.dart';

void main() {
  setupLogger();

  StartupContext context = new StartupContext.fromStartupInfo();

  ModuleWidget<BLEScannerModuleModel> moduleWidget =
      new ModuleWidget<BLEScannerModuleModel>(
          moduleModel: new BLEScannerModuleModel(context),
          startupContext: context,
          child: new BLEScannerScreen())
        ..advertise();

  runApp(new MaterialApp(home: moduleWidget));
}
