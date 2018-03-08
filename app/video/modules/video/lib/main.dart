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

final String _kDefaultUrl = 'https://r1---sn-n4v7knl6.googlevideo.com/'
    'videoplayback?ipbits=0&lmt=1405094805516164&ip=172.17.31.100&'
    'sparams=clen%2Cdur%2Cei%2Cgir%2Cid%2Cip%2Cipbits%2Citag%2Clmt%2Cmime%2Cmm'
    '%2Cmn%2Cms%2Cmv%2Cpl%2Crequiressl%2Csource%2Cexpire&'
    'ei=eEOpWuDqMMLX-gOC5obgDQ&itag=17&requiressl=yes&'
    'id=o-AKlH_lVdVP16qwC1etzAonhDuHZIcu5HwZldftSUG6LR&mt=1521041439'
    '&expire=1521063896&mime=video%2F3gpp&key=yt6&mm=31%2C26&'
    'mn=sn-n4v7knl6%2Csn-woc7en76&clen=2787691&c=WEB&gir=yes&dur=273.345&'
    'fvip=9&pl=20&source=youtube&mv=u&ms=au%2Conr&'
    'signature=809E17D8CB7F7C759E00DC0044ADD85839971502.9B0837F2E40525EB23E214'
    '683DBDCD87965DA1DE';

bool _videoAssetInitialized;

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
        (Asset asset) => _handleSetAsset(asset, playerModel, moduleDriver),
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

void _handleSetAsset(
    Asset asset, PlayerModel playerModel, ModuleDriver module) {
  if (asset == null) {
    log.info('null Asset received in video module');
    if (!_videoAssetInitialized) {
      log.fine('video module started. Setting default video.');
      _handleSetAsset(
          new Asset.movie(
            uri: Uri.parse(_kDefaultUrl),
            title: '',
            description: '',
            thumbnail: '',
            background: '',
          ),
          playerModel,
          module);
    }
    return;
  }
  log.info('video module received Asset with uri: ${asset?.uri?.toString()}');
  _videoAssetInitialized = true;
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
