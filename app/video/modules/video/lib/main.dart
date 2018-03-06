// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/model.dart' show ScopedModel;

import 'asset.dart';
import 'asset_entity_codec.dart';
import 'src/modular/player_model.dart';
import 'src/widgets.dart';
import 'video_progress.dart';
import 'video_progress_entity_codec.dart';

final String _kDefaultUrl =
    'https://storage.googleapis.com/fuchsia/assets/video/'
    '656a7250025525ae5a44b43d23c51e38b466d146';

final AssetEntityCodec _assetCodec = new AssetEntityCodec();
final VideoProgressEntityCodec _progressCodec = new VideoProgressEntityCodec();

void main() {
  setupLogger(
    name: 'video',
    level: Level.INFO,
  );

  ModuleDriver moduleDriver = new ModuleDriver();

  PlayerModel playerModel = new PlayerModel(
    environmentServices: moduleDriver.environmentServices,
    notifyProgress: (VideoProgress progress) {
      moduleDriver.put('video_progress', progress, _progressCodec);
    },
  );

  moduleDriver.watch('set_asset', _assetCodec, all: true).listen(
      (Asset asset) => _handleAssetChanged(asset, playerModel),
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

void _handleStart(ModuleDriver module, PlayerModel playerModel) {
  log.fine('video module started. Setting default video.');

  // TODO MS-1290 Add logic to only do this if no other video is specified
  module.put(
      'set_asset',
      new Asset.movie(
        uri: Uri.parse(_kDefaultUrl),
        title: '',
        description: '',
        thumbnail: '',
        background: '',
        ),
      _assetCodec);
}

void _handleAssetChanged(Asset asset, PlayerModel playerModel) {
  if (asset == null) {
    log.info('null Asset received in video module');
    return;
  }
  log.info('video module received Asset with uri: ${asset?.uri?.toString()}');
  playerModel.asset = asset;
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
