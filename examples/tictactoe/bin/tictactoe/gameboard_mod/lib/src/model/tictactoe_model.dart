// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';
import 'package:tictactoe_common/common.dart';

typedef WinListener = void Function(GameState winner);

class TicTacToeModel extends Model {
  GameState gameState = GameState.inProgress;

  Game _game = new Game();
  WinListener _winListener;

  TicTacToeModel({WinListener winListener}) {
    _winListener = winListener;
  }

  /// Both row and column should be between 0 and 2 inclusive.
  SquareState getSquareState(int row, int column) =>
      _game.board.getSquare(row, column).state;

  /// Both row and column should be between 0 and 2 inclusive.
  void playSquare(int row, int column) {
    if (getSquareState(row, column) != SquareState.empty ||
        gameState != GameState.inProgress) {
      return;
    }
    gameState = _game.playTurn(_game.board.getSquare(row, column));
    if (_winListener != null) {
      _winListener(gameState);
    }
    notifyListeners();
  }

  void restartGame() {
    _game = new Game();
    gameState = GameState.inProgress;
    notifyListeners();
  }
}
