// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:config/config.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';
import 'src/modular/screen.dart';

const String _kUspsApiKey = 'usps_api_key';

Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>[_kUspsApiKey]);
  return config.get(_kUspsApiKey);
}

Future<Null> main() async {
  String uspsApiKey = await _readAPIKey();

  ModuleWidget<UspsModuleModel> moduleWidget =
      new ModuleWidget<UspsModuleModel>(
    applicationContext: new ApplicationContext.fromStartupInfo(),
    moduleModel: new UspsModuleModel(),
    child: new UspsScreen(apiKey: uspsApiKey),
  );

  moduleWidget.advertise();
  runApp(moduleWidget);
}
