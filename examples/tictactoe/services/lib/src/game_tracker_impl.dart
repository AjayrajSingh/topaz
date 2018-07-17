// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart' as fidl;
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:tictactoe_common/common.dart';

class GameTrackerImpl extends GameTracker {
  final ComponentContext _componentContext;
  final Map<String, Future<fidl.MessageSenderProxy>> _messageQueues = {};
  // TODO(MS-1868) watch for score changes from sledge and put those changes
  // on the message queues.
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
  void recordWin(Player player) async {
    // TODO(MS-1858): Handle update errors.
    await _sledge.runInTransaction(() async {
      dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
      if (player == Player.x) {
        doc.xScore.value++;
      } else {
        doc.oScore.value++;
      }

      log
        ..infoT('Player $player won')
        ..infoT('Current score x: ${doc.xScore.value}  o: ${doc.oScore.value}');
    });
  }

  @override
  void subscribeToScore(String queueToken) {
    _messageQueues[queueToken] = _createMessageSenderProxy(queueToken);
    _sendScoreToQueue(queueToken);
  }

  @override
  void unsubscribeFromScore(String queueToken) {
    _messageQueues.remove(queueToken);
  }

  Future<Score> _getScore() async {
    // TODO(MS-1858): Handle fetch errors.
    Completer<Score> score = Completer();
    await _sledge.runInTransaction(() async {
      dynamic doc = await _sledge.getDocument(_sledgeDocumentId);
      if (doc?.xScore?.value is int && doc?.oScore?.value is int) {
        score.complete(Score(doc.xScore.value, doc.oScore.value));
      } else {
        score.completeError('Unable to retrieve score');
      }
    });

    return score.future;
  }

  void _sendScoreToQueue(String queueToken) {
    // TODO(MS-1858): Handle sending errors.
    _getScore().then((score) => _messageQueues[queueToken]
        .then((proxy) => proxy.send(_scoreCodec.encode(score))));
  }

  Future<fidl.MessageSenderProxy> _createMessageSenderProxy(String queueToken) {
    Completer<fidl.MessageSenderProxy> senderCompleter =
        new Completer<fidl.MessageSenderProxy>();
    fidl.MessageSenderProxy sender = new fidl.MessageSenderProxy();

    sender.ctrl.error.then((ProxyError err) {
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
