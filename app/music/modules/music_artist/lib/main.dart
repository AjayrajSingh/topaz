// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_widgets/music_widgets.dart';

import 'modular/artist_surface_model.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  // TODO(dayang@): Actually get the ID from the link store
  ArtistSurfaceModel albumSurfaceModel = new ArtistSurfaceModel(
    artistId: '6E1rccfBuIsyLUBH81PYoG',
  );

  ModuleWidget<ArtistSurfaceModel> moduleWidget =
      new ModuleWidget<ArtistSurfaceModel>(
    applicationContext: applicationContext,
    moduleModel: albumSurfaceModel,
    child: new Scaffold(
      backgroundColor: Colors.grey[300],
      body: new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ScopedModelDescendant<ArtistSurfaceModel>(builder: (
          _,
          __,
          ArtistSurfaceModel model,
        ) {
          return new ArtistSurface(
            artist: model.artist,
            albums: model.albums,
            relatedArtists: model.relatedArtists,
            loadingStatus: model.loadingStatus,
            // TODO(dayang@): hook up other actions to real stuff
          );
        }),
      ),
    ),
  );

  runApp(moduleWidget);
  albumSurfaceModel.fetchArtist();
  moduleWidget.advertise();
}
