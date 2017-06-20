// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'modular/artist_bio_module_model.dart';
import 'modular/artist_bio_module_screen.dart';

/// Retrieves the Songkick API Key
Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['last_fm_api_key']);
  return config.get('last_fm_api_key');
}

Future<Null> main() async {
  setupLogger();

  String apiKey = await _readAPIKey();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  ArtistBioModuleModel artistBioModuleModel = new ArtistBioModuleModel(
    apiKey: apiKey,
  );

  ModuleWidget<ArtistBioModuleModel> moduleWidget =
      new ModuleWidget<ArtistBioModuleModel>(
    applicationContext: applicationContext,
    moduleModel: artistBioModuleModel,
    child: new ArtistBioModuleScreen(),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
