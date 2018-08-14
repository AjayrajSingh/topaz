// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'package:tictactoe_common/common.dart';

void main() {
  test('in progress', () {
    expect(
        _playGame([
          [1, 1],
          [0, 2]
        ]),
        GameState.inProgress);
  });

  test('x wins', () {
    expect(
        _playGame([
          [1, 1],
          [0, 2],
          [2, 2],
          [1, 2],
          [0, 0]
        ]),
        GameState.xWin);
  });

  test('o wins', () {
    expect(
        _playGame([
          [1, 0],
          [0, 0],
          [2, 1],
          [2, 2],
          [0, 1],
          [1, 1]
        ]),
        GameState.oWin);
  });

  test('cats game', () {
    expect(
        _playGame([
          [0, 0],
          [0, 1],
          [0, 2],
          [1, 1],
          [1, 0],
          [2, 2],
          [1, 2],
          [2, 0],
          [2, 1]
        ]),
        GameState.cats);
  });
}

/// [plays] is a list of plays where each play is a row, column.
GameState _playGame(List<List<int>> plays) {
  Game game = new Game();
  Board board = game.board;
  List<Square> squaresToPlay = plays
      .map((playCoordinates) =>
          board.getSquare(playCoordinates[0], playCoordinates[1]))
      .toList();
  GameState state;
  for (int i = 0; i < plays.length; i++) {
    state = game.playTurn(squaresToPlay[i]);
  }
  return state;
}
