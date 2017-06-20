// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:config/config.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';
import 'src/modular/screen.dart';

const String _kGoogleApiKey = 'google_api_key';

Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>[_kGoogleApiKey]);
  return config.get(_kGoogleApiKey);
}

Future<Null> main() async {
  setupLogger();

  String googleApiKey = await _readAPIKey();

  ModuleWidget<MapModuleModel> moduleWidget = new ModuleWidget<MapModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new MapModuleModel(),
    child: new MapScreen(apiKey: googleApiKey),
  );

  moduleWidget.advertise();
  runApp(moduleWidget);
}
