// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'board.dart';
import 'square.dart';
import 'win_detection.dart';

// Note: a [cats] game is a tied where no empty squares remain.
enum GameState { xWin, oWin, cats, inProgress }

class Game {
  Board board = new Board();

  /// Play next turn at square [play]. Every odd numbered call to this method
  /// will result in an X being played and every even numbered call will
  /// result in a O being played.  This method should be called a maximum of
  /// 9 times and only ever on empty squares.
  GameState playTurn(Square play) {
    assert(play.state == SquareState.empty);
    play.state = _whoseTurn();
    return getGameState(board);
  }

  SquareState _whoseTurn() {
    if (board.xCount <= board.oCount) {
      return SquareState.x;
    } else {
      return SquareState.o;
    }
  }
}