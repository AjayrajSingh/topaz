// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.media.flutter/media_progress.dart';
import 'package:lib.schemas.dart/com/fuchsia/media/media.dart';
import 'package:lib.widgets/model.dart' show ScopedModel;

import 'src/asset.dart';
import 'src/modular/player_model.dart';
import 'src/widgets.dart';

const String _kDefaultUrl =
    'https://storage.googleapis.com/fuchsia/assets/video/'
    '656a7250025525ae5a44b43d23c51e38b466d146';

bool _videoAssetInitialized = false;

final AssetSpecifierEntityCodec _assetSpecifierCodec =
    new AssetSpecifierEntityCodec();
final MediaProgressEntityCodec _mediaProgressCodec =
    new MediaProgressEntityCodec();

void main() {
  setupLogger(
    name: 'video',
    level: Level.INFO,
  );

  PlayerModel playerModel;
  ModuleDriver moduleDriver = new ModuleDriver(onTerminate: () {
    playerModel?.terminate();
  });

  playerModel = new PlayerModel(
    environmentServices: moduleDriver.environmentServices,
    notifyProgress: (MediaProgress progress) {
      moduleDriver.put(
          'media_progress', progress.toEntity(), _mediaProgressCodec);
    },
  );

  moduleDriver.watch('media_asset', _assetSpecifierCodec, all: true).listen(
        (AssetSpecifierEntityData assetSpecifierEntityData) =>
            _handleAssetSpecifierChanged(
                assetSpecifierEntityData, playerModel, moduleDriver),
        cancelOnError: false,
        onError: _handleAssetEntityError,
        onDone: () => log.fine('video player update stream closed'),
      );

  moduleDriver.start().then(
        (ModuleDriver module) => _handleStart(module, playerModel),
        onError: _handleStartupError,
      );

  ScopedModel<PlayerModel> moduleWidget = new ScopedModel<PlayerModel>(
    model: playerModel,
    child: new MaterialApp(
      title: 'Video Player',
      home: const Material(
        child: const Player(),
      ),
    ),
  );

  runApp(moduleWidget);
}

void _handleStart(ModuleDriver module, PlayerModel playerModel) {}

// This method converts AssetSpecifierEntityData to an Asset and uses the legacy
// method (until step 3 of MS-1308).
void _handleAssetSpecifierChanged(
    AssetSpecifierEntityData assetSpecifierEntityData,
    PlayerModel playerModel,
    ModuleDriver module) {
  if (assetSpecifierEntityData == null) {
    log.info('null AssetSpecifier received in video module');
    if (!_videoAssetInitialized) {
      log.fine('video module started. Setting default video.');
      _handleAssetSpecifierChanged(
          new AssetSpecifierEntityData.movie(uri: _kDefaultUrl),
          playerModel,
          module);
    }
    return;
  }

  log.info(
      'video module received Asset with uri: ${assetSpecifierEntityData?.uri}');
  _videoAssetInitialized = true;
  playerModel.asset = new Asset.fromEntity(assetSpecifierEntityData);
}

// TODO(SO-1123): hook up to a snackbar.
void _handleAssetEntityError(Error error, StackTrace stackTrace) {
  log.severe('An error occurred reading Asset Entity', error, stackTrace);
}

// Generic error handler.
// TODO(SO-1123): hook up to a snackbar.
void _handleStartupError(Error error, StackTrace stackTrace) {
  log.severe('Error initializing video module', error, stackTrace);
}
