// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_tictactoe/fidl_async.dart';
import 'package:flutter/material.dart';
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
  setupLogger(name: 'tictactoe game board');

  // The ModuleDriver is a dart-idomatic interface to the Fuchsia system.
  ModuleDriver moduleDriver = new ModuleDriver()
    ..start().then((_) => trace('module is ready')).catchError(
        (error, stackTrace) =>
            log.severe('Error starting module driver.', error, stackTrace));

  Future<GameTracker> gameTracker = _createGameTracker(moduleDriver);

  TicTacToeModel model = new TicTacToeModel(
    winListener: (gameState) async =>
        _recordWinner(await gameTracker, gameState),
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

Future<GameTracker> _createGameTracker(ModuleDriver moduleDriver) async {
  GameTrackerProxy gameTrackerProxy = new GameTrackerProxy();
  return moduleDriver
      .connectToAgentServiceWithAsyncProxy(
        gameTrackerAgentUrl,
        gameTrackerProxy,
      )
      .then((_) => gameTrackerProxy)
      .catchError(
        (error, stackTrace) =>
            log.severe('Error constructing GameTracker.', error, stackTrace),
      );
}

void _recordWinner(
  GameTracker gameTracker,
  GameState gameState,
) async {
  try {
    if (gameState == GameState.xWin) {
      await gameTracker.recordWin(Player.x);
    } else if (gameState == GameState.oWin) {
      await gameTracker.recordWin(Player.o);
    }
    // ignore: avoid_catches_without_on_clauses
  } catch (error, stackTrace) {
    log.severe('Error recording win', error, stackTrace);
  }
}

Future<void> _proposeScore(ModuleDriver moduleDriver) async {
  final storyId = await moduleDriver.getStoryId();

  final Intent intent = Intent(handler: scoreBoardModUrl);

  final AddModule addModule = AddModule(
    moduleName: 'ScoreBoard',
    surfaceRelation: const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
      emphasis: 0.3,
    ),
    intent: intent,
    // This parameter is the parent module. In our case, it would be
    // game board mod. We would use 'root' to denote that.
    surfaceParentModulePath: ['root'],
  );

  final proposalBuilder =
      ProposalBuilder(id: 'showScore', headline: 'Show Score')
        ..storyId = storyId
        ..color = suggestionColor
        ..storyAffinity = true
        ..addAction(Action.withAddModule(addModule));

  final intelligenceServices =
      await moduleDriver.moduleContext.getIntelligenceServices();

  final ProposalPublisherProxy proposalPublisher = ProposalPublisherProxy();
  intelligenceServices.getProposalPublisher(proposalPublisher.ctrl.request());
  proposalPublisher.propose(await proposalBuilder.build());
}
