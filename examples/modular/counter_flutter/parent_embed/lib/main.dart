// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'home.dart';
import 'module_model.dart';

void main() {
  setupLogger(name: 'counter_parent_embed');

  ModuleWidget<CounterParentModuleModel> moduleWidget =
      new ModuleWidget<CounterParentModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new CounterParentModuleModel(),
    child: new MaterialApp(
      home: new Home(),
    ),
  );

  moduleWidget.advertise();
  runApp(moduleWidget);
}
