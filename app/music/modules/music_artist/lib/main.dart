// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'modular/artist_module_model.dart';
import 'modular/artist_module_screen.dart';

Future<Null> main() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['spotify_client_id', 'spotify_client_secret']);

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  ArtistModuleModel artistModuleModel = new ArtistModuleModel(
    clientId: config.get('spotify_client_id'),
    clientSecret: config.get('spotify_client_secret'),
  );

  ModuleWidget<ArtistModuleModel> moduleWidget =
      new ModuleWidget<ArtistModuleModel>(
    applicationContext: applicationContext,
    moduleModel: artistModuleModel,
    child: new ArtistModuleScreen(),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
