// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:lib.app_driver.dart/module_driver.dart';

class GameTrackerServiceClient extends ServiceClient<GameTracker> {
  GameTrackerProxy _proxy;

  GameTrackerServiceClient() : super(new GameTrackerProxy()) {
    _proxy = super.proxy;
  }

  void recordWin(Player player) {
    // TODO(MS-1858): Handle errors from service.
    _proxy.recordWin(player);
  }

  void subscribeToScore(String queueToken) {
    // TODO(MS-1858): Handle errors from service.
    _proxy.subscribeToScore(queueToken);
  }

  void unsubscribeFromScore(String queueToken) {
    // TODO(MS-1858): Handle errors from service.
    _proxy.unsubscribeFromScore(queueToken);
  }
}
