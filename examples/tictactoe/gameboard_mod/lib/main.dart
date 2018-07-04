// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:flutter/material.dart';
import 'package:game_tracker_client/client.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets/modular.dart';
import 'package:tictactoe_common/common.dart';

import 'src/model/tictactoe_model.dart';
import 'src/widget/tictactoe_board.dart';

const String gameTrackerAgentUrl = 'game_tracker_agent';

void main() {
  setupLogger(name: 'tictactoe gameboard');

  // The ModuleDriver is a dart-idomatic interfacer to the Fuchsia system.
  Future<ModuleDriver> driver = new ModuleDriver()
      .start()
      .catchError((e, t) => log.severe('Error starting module driver.', e, t));

  // A ServiceClient is a temporary construct for providing idiomatic,
  // async Dart APIs for clients of a FIDL service.  ServiceClients will be
  // removed when the new dart FIDL bindings are available.
  Future<GameTrackerServiceClient> gameTrackerServiceClient = driver
      .then(_createGameTrackerServiceClient)
      .catchError((e, t) =>
          log.severe('Error constructing GameTrackerServiceClient.', e, t));

  TicTacToeModel model = new TicTacToeModel(
    winListener: (gameState) async =>
        _recordWinner(await gameTrackerServiceClient, gameState),
  );

  runApp(
    MaterialApp(
      home: Material(
        child: ScopedModel<TicTacToeModel>(
          model: model,
          child: new TicTacToeBoard(),
        ),
      ),
    ),
  );
}

Future<GameTrackerServiceClient> _createGameTrackerServiceClient(
    ModuleDriver moduleDriver) async {
  GameTrackerServiceClient gameTrackerServiceClient =
      new GameTrackerServiceClient();
  moduleDriver.addOnTerminateHandler(() => gameTrackerServiceClient.terminate);
  await moduleDriver.connectToAgentService(
    gameTrackerAgentUrl,
    gameTrackerServiceClient,
  );
  return gameTrackerServiceClient;
}

void _recordWinner(
  GameTrackerServiceClient gameTrackerServiceClient,
  GameState gameState,
) {
  if (gameState == GameState.xWin) {
    gameTrackerServiceClient.recordWin(Player.x);
  } else if (gameState == GameState.oWin) {
    gameTrackerServiceClient.recordWin(Player.o);
  }
}
