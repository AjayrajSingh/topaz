// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:lib.app.dart/logging.dart';

class GameTrackerImpl extends GameTracker {
  // TODO persist this info since it will be lost when the agent goes down
  int _xScore = 0;
  int _oScore = 0;

  @override
  void recordWin(Player player) {
    if (player == Player.x) {
      _xScore++;
    } else {
      _oScore++;
    }
    log
      ..infoT('Player $player won')
      ..infoT('Current score x: $_xScore  o: $_oScore');
  }
}
