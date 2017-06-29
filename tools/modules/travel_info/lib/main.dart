// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/travel_info_module_model.dart';
import 'src/modular/travel_info_module_screen.dart';

Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['google_api_key']);
  return config.get('google_api_key');
}

Future<Null> main() async {
  setupLogger(name: 'Travel Info Module');

  String apiKey = await _readAPIKey();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  TravelInfoModuleModel travelInfoModuleModel =
      new TravelInfoModuleModel(apiKey: apiKey);

  ModuleWidget<TravelInfoModuleModel> moduleWidget =
      new ModuleWidget<TravelInfoModuleModel>(
    applicationContext: applicationContext,
    moduleModel: travelInfoModuleModel,
    child: new TravelInfoModuleScreen(),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
