// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';

import 'modular/artist_module_model.dart';

void main() {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  ArtistModuleModel artistModuleModel = new ArtistModuleModel();

  ModuleWidget<ArtistModuleModel> moduleWidget =
      new ModuleWidget<ArtistModuleModel>(
    applicationContext: applicationContext,
    moduleModel: artistModuleModel,
    child: new Scaffold(
      backgroundColor: Colors.grey[300],
      body: new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ScopedModelDescendant<ArtistModuleModel>(builder: (
          _,
          __,
          ArtistModuleModel model,
        ) {
          return new ArtistScreen(
            artist: model.artist,
            albums: model.albums,
            relatedArtists: model.relatedArtists,
            loadingStatus: model.loadingStatus,
            onTapArtist: (Artist artist) => model.goToArtist(artist.id),
            onTapAblum: (Album album) => model.goToAlbum(album.id),
          );
        }),
      ),
    ),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
