// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/player_model.dart';
import 'src/modular/video_module_model.dart';
import 'src/widgets.dart';

void main() {
  setupLogger();

  ApplicationContext appContext = new ApplicationContext.fromStartupInfo();
  VideoModuleModel videoModuleModel = new VideoModuleModel(
    appContext: appContext,
  );
  PlayerModel playerModel = new PlayerModel(
    appContext: appContext,
    requestFocus: videoModuleModel.requestFocus,
    getDisplayMode: videoModuleModel.getDisplayMode,
    setDisplayMode: videoModuleModel.setDisplayMode,
    onPlayRemote: videoModuleModel.onPlayRemote,
    onPlayLocal: videoModuleModel.onPlayLocal,
  );
  ModuleWidget<VideoModuleModel> moduleWidget =
      new ModuleWidget<VideoModuleModel>(
    moduleModel: videoModuleModel,
    applicationContext: appContext,
    child: new ScopedModel<PlayerModel>(
      model: playerModel,
      child: const VideoApp(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
