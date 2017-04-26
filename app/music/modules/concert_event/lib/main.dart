// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'modular/event_module_model.dart';

/// Retrieves the Songkick API Key
Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['songkick_api_key']);
  return config.get('songkick_api_key');
}

Future<Null> main() async {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  String apiKey = await _readAPIKey();

  EventModuleModel eventModuleModel = new EventModuleModel(apiKey: apiKey);

  ModuleWidget<EventModuleModel> moduleWidget =
      new ModuleWidget<EventModuleModel>(
    applicationContext: applicationContext,
    moduleModel: eventModuleModel,
    child: new Scaffold(
      backgroundColor: Colors.grey[300],
      body: new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ScopedModelDescendant<EventModuleModel>(builder: (
          BuildContext context,
          Widget child,
          EventModuleModel model,
        ) {
          return new Container(
            constraints: new BoxConstraints(maxWidth: 320.0),
            child: new EventCard(
              event: model.event,
              loadingStatus: model.loadingStatus,
            ),
          );
        }),
      ),
    ),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
