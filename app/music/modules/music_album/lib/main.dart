// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_widgets/music_widgets.dart';

import 'modular/album_surface_model.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  // TODO(dayang@): Actually get the ID from the link store
  AlbumSurfaceModel albumSurfaceModel = new AlbumSurfaceModel(
    albumId: '3e3AbSasv8baYuhNRWylG5',
  );

  ModuleWidget<AlbumSurfaceModel> moduleWidget =
      new ModuleWidget<AlbumSurfaceModel>(
    applicationContext: applicationContext,
    moduleModel: albumSurfaceModel,
    child: new Scaffold(
      backgroundColor: Colors.grey[800],
      body: new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ScopedModelDescendant<AlbumSurfaceModel>(builder: (
          _,
          __,
          AlbumSurfaceModel model,
        ) {
          return new AlbumSurface(
            album: model.album,
            loadingStatus: model.loadingStatus,
            // TODO(dayang@): hook up other actions to real stuff
          );
        }),
      ),
    ),
  );

  runApp(moduleWidget);
  albumSurfaceModel.fetchAlbum();
  moduleWidget.advertise();
}
