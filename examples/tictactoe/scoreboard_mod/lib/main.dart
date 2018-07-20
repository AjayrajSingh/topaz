import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets/modular.dart';
import 'package:tictactoe_common/common.dart';
import 'package:game_tracker_client/client.dart';

import 'src/model/scoreboard_model.dart';
import 'src/widget/scoreboard_widget.dart';

const String scoreQueueName = 'score_name';
const String gameTrackerAgentUrl = 'game_tracker_agent';

void main() {
  setupLogger(name: 'score card mod');

  // The ModuleDriver is a dart-idomatic interfacer to the Fuchsia system.
  ModuleDriver moduleDriver = new ModuleDriver()
    ..start().then((_) => trace('module is ready')).catchError(
        (error, stackTrace) =>
            log.severe('Error starting module driver.', error, stackTrace));

  ScoreBoardModel model = ScoreBoardModel();
  ScoreCodec scoreCodec = ScoreCodec();

  // A ServiceClient is a temporary construct for providing idiomatic,
  // async Dart APIs for clients of a FIDL service.  ServiceClients will be
  // removed when the new dart FIDL bindings are available.
  // ignore: unused_local_variable
  Future<GameTrackerServiceClient> gameTrackerServiceClient =
      _createGameTrackerServiceClient(moduleDriver).catchError(
    (error, stackTrace) => log.severe(
        'Error constructing GameTrackerServiceClient.', error, stackTrace),
  );

  // Set up message queue to get score updates from.
  Future<String> messageQueueToken = moduleDriver
      .createMessageQueue(
        name: scoreQueueName,
        onReceive: (data, ack) {
          Score score = scoreCodec.decode(data);
          if (score != null) {
            model.setScore(score.xScore, score.oScore);
          }
          ack();
        },
      )
      .catchError(
        (error, stackTrace) =>
            log.severe('Error creating message queue', error, stackTrace),
      );

  // Subcribe to score updates.
  gameTrackerServiceClient.then(
    (gameTrackerServiceClient) async {
      return gameTrackerServiceClient.subscribeToScore(await messageQueueToken);
    },
  ).catchError((error, stackTrace) =>
      log.severe('Error subscribing to score', error, stackTrace));

  // Terminate connection to tracker service when the mod terminates.
  moduleDriver.addOnTerminateHandler(
    () => gameTrackerServiceClient.then((gameTrackerServiceClient) async {
          gameTrackerServiceClient
            ..unsubscribeFromScore(await messageQueueToken).catchError((error,
                    stackTrace) =>
                log.severe('Error unsubscribing from score', error, stackTrace))
            ..terminate();
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

Future<GameTrackerServiceClient> _createGameTrackerServiceClient(
    ModuleDriver moduleDriver) {
  GameTrackerServiceClient gameTrackerServiceClient =
      new GameTrackerServiceClient();
  return moduleDriver
      .connectToAgentService(
        gameTrackerAgentUrl,
        gameTrackerServiceClient,
      )
      .then((_) => gameTrackerServiceClient);
}
