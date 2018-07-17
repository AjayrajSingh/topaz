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
  Future<ModuleDriver> moduleDriver = new ModuleDriver().start().then(
    (moduleDriver) {
      trace('module is ready');
      return moduleDriver;
    },
  ).catchError((e, t) => log.severe('Error starting module driver.', e, t));

  ScoreBoardModel model = ScoreBoardModel();
  ScoreCodec scoreCodec = ScoreCodec();

  // A ServiceClient is a temporary construct for providing idiomatic,
  // async Dart APIs for clients of a FIDL service.  ServiceClients will be
  // removed when the new dart FIDL bindings are available.
  // ignore: unused_local_variable
  Future<GameTrackerServiceClient> gameTrackerServiceClient = moduleDriver
      .then(_createGameTrackerServiceClient)
      .catchError(
        (e, t) =>
            log.severe('Error constructing GameTrackerServiceClient.', e, t),
      );

  // Set up message queue to get score updates from.
  Future<String> messageQueueToken = moduleDriver.then((moduleDriver) {
    return moduleDriver
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
          (e, t) => log.severe('Error creating message queue', e, t),
        );
  });

  // Subcribe to score updates.
  gameTrackerServiceClient.then(
    (gameTrackerServiceClient) async {
      return gameTrackerServiceClient.subscribeToScore(await messageQueueToken);
    },
  ).catchError((e, t) => log.severe('Error subscribing to score', e, t));

  // Terminate connection to tracker service when the mod terminates.
  moduleDriver
      .then(
        (moduleDriver) => moduleDriver.addOnTerminateHandler(
              () => gameTrackerServiceClient
                      .then((gameTrackerServiceClient) async {
                    gameTrackerServiceClient
                      ..unsubscribeFromScore(await messageQueueToken)
                      ..terminate();
                  }),
            ),
      )
      .catchError(
        (e, t) =>
            log.severe('Error setting up tracker client termination.', e, t),
      );

  runApp(
    MaterialApp(
      home: Material(
          child: ScopedModel<ScoreBoardModel>(
        model: model,
        child: ScoreBoardWidget(),
      )),
    ),
  );
}

Future<GameTrackerServiceClient> _createGameTrackerServiceClient(
    ModuleDriver moduleDriver) {
  Completer<GameTrackerServiceClient> completer = Completer();
  GameTrackerServiceClient gameTrackerServiceClient =
      new GameTrackerServiceClient();
  moduleDriver
      .connectToAgentService(
        gameTrackerAgentUrl,
        gameTrackerServiceClient,
      )
      .then((_) => completer.complete(gameTrackerServiceClient));
  return completer.future;
}
