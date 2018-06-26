// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/board.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/game.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/square.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/win_detection.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('empty board', () {
    expect(
        getGameState(buildBoard([
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty
        ])),
        GameState.inProgress);
  });

  test('one move board', () {
    expect(
        getGameState(buildBoard([
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.x,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty,
          SquareState.empty
        ])),
        GameState.inProgress);
  });

  test('x win down board', () {
    expect(
        getGameState(buildBoard([
          SquareState.o,
          SquareState.x,
          SquareState.o,
          SquareState.empty,
          SquareState.x,
          SquareState.empty,
          SquareState.empty,
          SquareState.x,
          SquareState.o
        ])),
        GameState.xWin);
  });

  test('x win across board', () {
    expect(
        getGameState(buildBoard([
          SquareState.x,
          SquareState.x,
          SquareState.x,
          SquareState.empty,
          SquareState.o,
          SquareState.empty,
          SquareState.empty,
          SquareState.o,
          SquareState.empty
        ])),
        GameState.xWin);
  });

  test('x win diagonal board', () {
    expect(
        getGameState(buildBoard([
          SquareState.x,
          SquareState.o,
          SquareState.empty,
          SquareState.empty,
          SquareState.x,
          SquareState.empty,
          SquareState.empty,
          SquareState.o,
          SquareState.x
        ])),
        GameState.xWin);
  });

  test('x win anti-diagonal board', () {
    expect(
        getGameState(buildBoard([
          SquareState.o,
          SquareState.o,
          SquareState.x,
          SquareState.empty,
          SquareState.x,
          SquareState.empty,
          SquareState.x,
          SquareState.o,
          SquareState.x
        ])),
        GameState.xWin);
  });

  test('o win down board', () {
    expect(
        getGameState(buildBoard([
          SquareState.o,
          SquareState.empty,
          SquareState.o,
          SquareState.empty,
          SquareState.x,
          SquareState.o,
          SquareState.empty,
          SquareState.x,
          SquareState.o
        ])),
        GameState.oWin);
  });

  test('o win across board', () {
    expect(
        getGameState(buildBoard([
          SquareState.x,
          SquareState.x,
          SquareState.o,
          SquareState.o,
          SquareState.o,
          SquareState.o,
          SquareState.empty,
          SquareState.x,
          SquareState.empty
        ])),
        GameState.oWin);
  });

  test('o win diagonal board', () {
    expect(
        getGameState(buildBoard([
          SquareState.o,
          SquareState.x,
          SquareState.empty,
          SquareState.empty,
          SquareState.o,
          SquareState.empty,
          SquareState.empty,
          SquareState.x,
          SquareState.o
        ])),
        GameState.oWin);
  });

  test('o win anti-diagonal board', () {
    expect(
        getGameState(buildBoard([
          SquareState.x,
          SquareState.x,
          SquareState.o,
          SquareState.empty,
          SquareState.o,
          SquareState.empty,
          SquareState.o,
          SquareState.x,
          SquareState.x
        ])),
        GameState.oWin);
  });

  test('cats board', () {
    expect(
        getGameState(buildBoard([
          SquareState.x,
          SquareState.o,
          SquareState.x,
          SquareState.x,
          SquareState.x,
          SquareState.o,
          SquareState.o,
          SquareState.x,
          SquareState.o
        ])),
        GameState.cats);
  });
}

Board buildBoard(List<SquareState> states) {
  return new Board.withSquares(new List.generate(
      9, (i) => new Square(states[i])));
}
