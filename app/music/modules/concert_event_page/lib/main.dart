// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:concert_widgets/concert_widgets.dart';
import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'modular/event_page_module_model.dart';

/// Retrieves the Songkick API Key
Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json')
    ..validate(<String>['songkick_api_key']);
  return config.get('songkick_api_key');
}

Future<Null> main() async {
  setupLogger();

  String apiKey = await _readAPIKey();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  EventPageModuleModel eventPageModuleModel =
      new EventPageModuleModel(apiKey: apiKey);

  ModuleWidget<EventPageModuleModel> moduleWidget =
      new ModuleWidget<EventPageModuleModel>(
    applicationContext: applicationContext,
    moduleModel: eventPageModuleModel,
    child: new Material(
      elevation: 1.0,
      child: new ScopedModelDescendant<EventPageModuleModel>(builder: (
        BuildContext context,
        Widget child,
        EventPageModuleModel model,
      ) {
        return new Loader(
          loadingStatus: model.loadingStatus,
          builder: (BuildContext context) => new SingleChildScrollView(
                child: new EventPage(
                  event: model.event,
                  onTapBuy: model.purchaseTicket,
                ),
              ),
        );
      }),
    ),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
