// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:widgets/shopping.dart';

void main() {
  ModuleWidget<ModuleModel> moduleWidget = new ModuleWidget<ModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new ModuleModel(),
    child: new Material(
      child: new InteractiveReceipt(),
    ),
  );

  moduleWidget.advertise();

  runApp(moduleWidget);
}
