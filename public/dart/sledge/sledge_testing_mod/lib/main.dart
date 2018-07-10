// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/modular.dart';
import 'test_module_model.dart';

/// Main entry point to the testing mod.
void main() {
  StartupContext startupContext = new StartupContext.fromStartupInfo();

  TestModuleModel testModuleModel = new TestModuleModel();

  MaterialApp materialApp = new MaterialApp(
      home: new Text('This mod tests Sledge.'));

  ModuleWidget<TestModuleModel> testWidget = new ModuleWidget<TestModuleModel>(
    startupContext: startupContext,
    moduleModel: testModuleModel,
    child: materialApp,
  );

  runApp(testWidget);
  testWidget.advertise();
}
