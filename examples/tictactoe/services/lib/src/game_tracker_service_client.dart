// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:lib.app_driver.dart/module_driver.dart';

class GameTrackerServiceClient extends ServiceClient<GameTracker> {
  GameTrackerProxy _proxy;

  GameTrackerServiceClient() : super(new GameTrackerProxy()) {
    _proxy = super.proxy;
  }

  Future<void> recordWin(Player player) {
    Completer completer = new Completer();
    _proxy.recordWin(
        player, (executeResult) => _complete(completer, executeResult));
    return completer.future;
  }

  Future<void> subscribeToScore(String queueToken) {
    Completer completer = new Completer();
    _proxy.subscribeToScore(
        queueToken, (executeResult) => _complete(completer, executeResult));
    return completer.future;
  }

  Future<void> unsubscribeFromScore(String queueToken) {
    Completer completer = new Completer();
    _proxy.unsubscribeFromScore(
        queueToken, (executeResult) => _complete(completer, executeResult));
    return completer.future;
  }

  void _complete(Completer completer, ExecuteResult executeResult) {
    if (executeResult.status == Status.ok) {
      completer.complete(null);
    } else {
      completer.completeError(Exception(executeResult.errorMessage));
    }
  }
}
