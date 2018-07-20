// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl.dart' as fidl;
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl_fuchsia_tictactoe/fidl.dart' as tictactoe_fidl;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:tictactoe_common/common.dart';

typedef ExecuteResultFunction = void Function(
    tictactoe_fidl.ExecuteResult result);

class GameTrackerImpl extends tictactoe_fidl.GameTracker {
  final ComponentContext _componentContext;
  final Map<String, fidl.MessageSenderProxy> _messageQueues = {};
  final Map<String, StreamSubscription> _xSubscriptions = {};
  final Map<String, StreamSubscription> _oSubscriptions = {};
  final Sledge _sledge;
  final ScoreCodec _scoreCodec = ScoreCodec();

  DocumentId _sledgeDocumentId;

  GameTrackerImpl(this._componentContext)
      : _sledge = new Sledge(_componentContext) {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'xScore': new Integer(),
      'oScore': new Integer()
    };

    Schema schema = new Schema(schemaDescription);
    _sledgeDocumentId = new DocumentId.fromIntId(schema, 0);
  }

  @override
  void recordWin(tictactoe_fidl.Player player,
      ExecuteResultFunction resultFunction) async {
    try {
      bool transactionResult = await _sledge.runInTransaction(() async {
        dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
        if (doc == null) {
          throw Exception('Failure get document from sledge.');
        }

        if (player == tictactoe_fidl.Player.x) {
          doc.xScore.value++;
        } else {
          doc.oScore.value++;
        }

        log
          ..infoT('Player $player won')
          ..infoT(
              'Current score x: ${doc.xScore.value}  o: ${doc.oScore.value}');
      });
      if (transactionResult == false) {
        throw Exception('Error writing result to sledge.');
      }
      resultFunction(
          tictactoe_fidl.ExecuteResult(status: tictactoe_fidl.Status.ok));
    } on Exception catch (e) {
      resultFunction(tictactoe_fidl.ExecuteResult(
          status: tictactoe_fidl.Status.error, errorMessage: e.toString()));
    }
  }

  @override
  void subscribeToScore(
      String queueToken, ExecuteResultFunction resultFunction) async {
    try {
      _messageQueues[queueToken] = await _createMessageSenderProxy(queueToken);
      _setupScoreListeners(queueToken);
      _sendScoreToQueue(queueToken);
      resultFunction(
          tictactoe_fidl.ExecuteResult(status: tictactoe_fidl.Status.ok));
    } on Exception catch (e) {
      resultFunction(tictactoe_fidl.ExecuteResult(
          status: tictactoe_fidl.Status.error, errorMessage: e.toString()));
    }
  }

  @override
  void unsubscribeFromScore(
      String queueToken, ExecuteResultFunction resultFunction) {
    try {
      _messageQueues.remove(queueToken);
      _xSubscriptions.remove(queueToken)?.cancel();
      _oSubscriptions.remove(queueToken)?.cancel();
      resultFunction(
          tictactoe_fidl.ExecuteResult(status: tictactoe_fidl.Status.ok));
    } on Exception catch (e) {
      resultFunction(tictactoe_fidl.ExecuteResult(
          status: tictactoe_fidl.Status.error, errorMessage: e.toString()));
    }
  }

  Future<Score> _getScore() async {
    Completer<Score> score = Completer();
    await _sledge.runInTransaction(() async {
      dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
      if (doc == null) {
        throw Exception('Failure get document from sledge.');
      }
      if (doc.xScore.value is int && doc.oScore.value is int) {
        score.complete(Score(doc.xScore.value, doc.oScore.value));
      } else {
        score.completeError('Unable to retrieve score from sledge.');
      }
    });

    return score.future;
  }

  void _setupScoreListeners(String queueToken) async {
    await _sledge.runInTransaction(() async {
      dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
      if (doc != null) {
        // TODO: With the completion of LE-529, we should be able to listen to
        // the whole document for changes rather than individual fields;
        // however, curently we can only listen to individual fields for
        // changes. The parameters to the listen functions on the individual
        // fields provide the updated values for the individual updated fields,
        // number of x or o wins. However, since on each update from ledger we
        // need to put a complete score, x and o wins, on the message queue,
        // we do a read of the complete score from ledger as part of
        // [_sendScoreToQueue] rather that relying on the parameters to the
        // listen functions.
        _xSubscriptions[queueToken] =
            doc.xScore.onChange.listen((_) => _sendScoreToQueue(queueToken));
        _oSubscriptions[queueToken] =
            doc.oScore.onChange.listen((_) => _sendScoreToQueue(queueToken));
      }
    });
  }

  void _sendScoreToQueue(String queueToken) {
    if (_messageQueues.containsKey(queueToken)) {
      log.shout('Message queue not found in tracker service.');
    }
    _getScore()
        .then((score) =>
            _messageQueues[queueToken].send(_scoreCodec.encode(score)))
        .catchError((e) =>
            log.shout('Error sending score to message queue: ${e.toString()}'));
  }

  Future<fidl.MessageSenderProxy> _createMessageSenderProxy(String queueToken) {
    Completer<fidl.MessageSenderProxy> senderCompleter =
        new Completer<fidl.MessageSenderProxy>();
    fidl.MessageSenderProxy sender = new fidl.MessageSenderProxy();

    sender.ctrl.error.then((fidl.ProxyError err) {
      if (!senderCompleter.isCompleted) {
        senderCompleter.completeError(err);
      }
    });

    _componentContext.getMessageSender(queueToken, sender.ctrl.request());

    scheduleMicrotask(() {
      if (!senderCompleter.isCompleted) {
        senderCompleter.complete(sender);
      }
    });

    return senderCompleter.future;
  }
}
