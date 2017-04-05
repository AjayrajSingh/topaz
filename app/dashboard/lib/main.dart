// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'dashboard_app.dart';

void main() {
  ModuleWidget<ModuleModel> moduleWidget = new ModuleWidget<ModuleModel>(
    moduleModel: new ModuleModel(),
    child: new DashboardApp(),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
}
