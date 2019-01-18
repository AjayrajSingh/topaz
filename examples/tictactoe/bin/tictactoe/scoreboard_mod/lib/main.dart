import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fidl_fuchsia_tictactoe/fidl_async.dart';
import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets/modular.dart';
import 'package:tictactoe_common/common.dart';

import 'src/model/scoreboard_model.dart';
import 'src/widget/scoreboard_widget.dart';

const String scoreQueueName = 'score_name';
const String gameTrackerAgentUrl = 'game_tracker_agent';

void main() {
  setupLogger(name: 'score card mod');

  // The ModuleDriver is a dart-idomatic interfacer to the Fuchsia system.
  //
  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  ModuleDriver moduleDriver = new ModuleDriver()
    ..start().then((_) => trace('module is ready')).catchError(
        (error, stackTrace) =>
            log.severe('Error starting module driver.', error, stackTrace));

  ScoreBoardModel model = ScoreBoardModel();
  ScoreCodec scoreCodec = ScoreCodec();

  Future<GameTracker> futureGameTracker = _createGameTracker(moduleDriver);

  // Set up message queue to get score updates from.
  Future<String> messageQueueToken = moduleDriver
      .createMessageQueue(
        name: scoreQueueName,
        onMessage: (Uint8List data, void ack()) {
          Score score = scoreCodec.decode(utf8.decode(data));
          if (score != null) {
            model.setScore(score.xScore, score.oScore);
          }
          ack();
        },
        onConnectionError: (code, errMsg) {
          log.severe('Message Queue down: $errMsg');
        },
      )
      .catchError(
        (error, stackTrace) =>
            log.severe('Error creating message queue', error, stackTrace),
      );

  // Subcribe to score updates.
  futureGameTracker.then(
    (gameTracker) async {
      return gameTracker.subscribeToScore(await messageQueueToken);
    },
  ).catchError((error, stackTrace) =>
      log.severe('Error subscribing to score', error, stackTrace));

  // Terminate connection to tracker service when the mod terminates.
  moduleDriver.addOnTerminateHandler(
    () => futureGameTracker.then((gameTracker) async {
          await gameTracker
              .unsubscribeFromScore(await messageQueueToken)
              .catchError((error, stackTrace) => log.severe(
                  'Error unsubscribing from score', error, stackTrace));
        }),
  );

  runApp(
    MaterialApp(
      home: Material(
        child: ScopedModel<ScoreBoardModel>(
          model: model,
          child: ScoreBoardWidget(),
        ),
      ),
    ),
  );
}

// TODO: Refactor this class to use the new SDK instead of deprecated API
// ignore: deprecated_member_use
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
