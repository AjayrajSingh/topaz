// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:fuchsia.fidl.music/music.dart';

import 'models/playback_model.dart';
import 'widgets/scaffold.dart';

void main() {
  setupLogger();

  //TODO(chaselatta) MS-1424. Make this module use an Entity instead of a
  //fidl service to get the current song which is being played.

  PlaybackModel model = new PlaybackModel(
    player: new PlayerProxy(),
  );

  // Start the Module Driver
  new ModuleDriver(
    onTerminateFromCaller: () {
      model.disconnectFromPlayer();
      model.player.ctrl.close();
    },
  )
    ..connectToAgentServiceWithProxy('music_playback_agent', model.player).then(
        (_) {
      log.info('Connected to agent');
    }, onError: (Error error) {
      log.severe('failed to connect to agent with error', error);
    })
    ..start().then(_handleStart, onError: _handleError);

  runApp(
    new MaterialApp(
      home: new ScopedModel<PlaybackModel>(
        model: model,
        child: new MusicPlaybackScaffold(),
      ),
    ),
  );
}

void _handleError(Error error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}

void _handleStart(ModuleDriver module) {
  log.info('feedback module ready');
}
