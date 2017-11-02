// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/browser_module_model.dart';
import 'src/widgets/browser_app.dart';

void main() {
  setupLogger();

  ApplicationContext appContext = new ApplicationContext.fromStartupInfo();

  // TODO(maryxia) SO-850 dynamically generate these tabs from providers
  /// List of Document Providers, in Tab format
  final List<Widget> tabs = <Widget>[
    const Tab(text: 'Local Storage'),
    const Tab(text: 'USB-1'),
    const Tab(text: 'USB-2'),
  ];

  ModuleWidget<BrowserModuleModel> moduleWidget =
      new ModuleWidget<BrowserModuleModel>(
    moduleModel: new BrowserModuleModel(),
    applicationContext: appContext,
    child: new BrowserApp(tabs: tabs),
  )..advertise();

  runApp(moduleWidget);
}
