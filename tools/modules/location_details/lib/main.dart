// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/location_details_module_model.dart';
import 'src/modular/location_details_module_screen.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  LocationDetailsModuleModel locationDetailsModuleModel =
      new LocationDetailsModuleModel();

  ModuleWidget<LocationDetailsModuleModel> moduleWidget =
      new ModuleWidget<LocationDetailsModuleModel>(
    applicationContext: applicationContext,
    moduleModel: locationDetailsModuleModel,
    child: new LocationsDetailModuleScreen(),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
