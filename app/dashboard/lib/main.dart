// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'dashboard_app.dart';
import 'dashboard_module_model.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  DashboardModuleModel dashboardModuleModel = new DashboardModuleModel(
    applicationContext: applicationContext,
  );

  ModuleWidget<DashboardModuleModel> moduleWidget =
      new ModuleWidget<DashboardModuleModel>(
    applicationContext: applicationContext,
    moduleModel: dashboardModuleModel,
    child: new DashboardApp(),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
  dashboardModuleModel.loadDeviceMap();
}
