// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:flutter/material.dart';
import 'package:game_tracker_client/client.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:lib.widgets/modular.dart';
import 'package:tictactoe_common/common.dart';

import 'src/model/tictactoe_model.dart';
import 'src/widget/tictactoe_board.dart';

const String gameTrackerAgentUrl = 'game_tracker_agent';
const String scoreBoardModUrl = 'tictactoe_scoreboard_mod';
const int suggestionColor = 0xFFA5A700;

void main() {
  setupLogger(name: 'tictactoe gameboard');

  // The ModuleDriver is a dart-idomatic interfacer to the Fuchsia system.
  ModuleDriver moduleDriver = new ModuleDriver()
    ..start().then((_) => trace('module is ready')).catchError(
        (error, stackTrace) =>
            log.severe('Error starting module driver.', error, stackTrace));

  // A ServiceClient is a temporary construct for providing idiomatic,
  // async Dart APIs for clients of a FIDL service.  ServiceClients will be
  // removed when the new dart FIDL bindings are available.
  Future<GameTrackerServiceClient> gameTrackerServiceClient =
      _createGameTrackerServiceClient(moduleDriver).catchError(
          (error, stackTrace) => log.severe(
              'Error constructing GameTrackerServiceClient.', error, stackTrace));

  TicTacToeModel model = new TicTacToeModel(
    winListener: (gameState) async =>
        _recordWinner(await gameTrackerServiceClient, gameState),
  );

  _proposeScore(moduleDriver);

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
    gameTrackerServiceClient.recordWin(Player.x).catchError(
        (error, stackTrace) => log.severe('Error recording win', error, stackTrace));
  } else if (gameState == GameState.oWin) {
    gameTrackerServiceClient.recordWin(Player.o).catchError(
        (error, stackTrace) => log.severe('Error recording win', error, stackTrace));
  }
}

void _proposeScore(ModuleDriver moduleDriver) {
  moduleDriver.getStoryId().then((storyId) {
    Intent intent = Intent(handler: scoreBoardModUrl);

    AddModule addModule = AddModule(
      storyId: storyId,
      moduleName: 'ScoreBoard',
      surfaceRelation: const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 0.3,
      ),
      intent: intent,
      // This parameter is the parent module. In our case, it would be
      // gameboard mod. We would use 'root' to denote that.
      surfaceParentModulePath: ['root'],
    );

    ProposalBuilder proposal =
        ProposalBuilder(id: 'showScore', headline: 'Show Score')
          ..storyId = storyId
          ..color = suggestionColor
          ..storyAffinity = true
          ..addAction(Action.withAddModule(addModule));

    moduleDriver.moduleContext
        .getIntelligenceServices()
        .then((final intelligenceServices) {
      final ProposalPublisherProxy proposalPublisher = ProposalPublisherProxy();
      intelligenceServices
          .getProposalPublisher(proposalPublisher.ctrl.request());
      proposal.build().then(proposalPublisher.propose);
    });
  });
}
