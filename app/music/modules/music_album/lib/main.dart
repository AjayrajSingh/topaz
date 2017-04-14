// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_widgets/music_widgets.dart';

import 'modular/album_module_model.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  AlbumModuleModel albumModuleModel = new AlbumModuleModel();

  ModuleWidget<AlbumModuleModel> moduleWidget =
      new ModuleWidget<AlbumModuleModel>(
    applicationContext: applicationContext,
    moduleModel: albumModuleModel,
    child: new Scaffold(
      backgroundColor: Colors.grey[300],
      body: new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ScopedModelDescendant<AlbumModuleModel>(builder: (
          _,
          __,
          AlbumModuleModel model,
        ) {
          return new AlbumScreen(
            album: model.album,
            loadingStatus: model.loadingStatus,
            // TODO(dayang@): hook up other actions to real stuff
          );
        }),
      ),
    ),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
