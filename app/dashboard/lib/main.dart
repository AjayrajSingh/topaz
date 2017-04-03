// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/widgets.dart';

import 'dashboard_app.dart';
import 'module_impl.dart';
import 'module_widget.dart';

void main() {
  ModuleWidget moduleWidget = new ModuleWidget(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    module: new ModuleImpl(),
    child: new DashboardApp(),
  );

  runApp(moduleWidget);

  moduleWidget.advertise();
}
