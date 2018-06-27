// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/board.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/game.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/square.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/win_detection.dart'; // ignore: avoid_relative_lib_imports

const SquareState _ = SquareState.empty;
const SquareState x = SquareState.x;
const SquareState o = SquareState.o;

void main() {
  test('empty board', () {
    expect(
        getGameState(buildBoard([
          [_, _, _],
          [_, _, _],
          [_, _, _],
        ])),
        GameState.inProgress);
  });

  test('one move board', () {
    expect(
        getGameState(buildBoard([
          [_, _, _],
          [_, x, _],
          [_, _, _],
        ])),
        GameState.inProgress);
  });

  test('x win down board', () {
    expect(
        getGameState(buildBoard([
          [o, x, o],
          [_, x, _],
          [_, x, o],
        ])),
        GameState.xWin);
  });

  test('x win across board', () {
    expect(
        getGameState(buildBoard([
          [x, x, x],
          [_, o, _],
          [_, o, _],
        ])),
        GameState.xWin);
  });

  test('x win diagonal board', () {
    expect(
        getGameState(buildBoard([
          [x, o, _],
          [_, x, _],
          [_, o, x],
        ])),
        GameState.xWin);
  });

  test('x win anti-diagonal board', () {
    expect(
        getGameState(buildBoard([
          [o, o, x],
          [_, x, _],
          [x, o, x],
        ])),
        GameState.xWin);
  });

  test('o win down board', () {
    expect(
        getGameState(buildBoard([
          [o, _, o],
          [_, x, o],
          [_, x, o],
        ])),
        GameState.oWin);
  });

  test('o win across board', () {
    expect(
        getGameState(buildBoard([
          [x, x, o],
          [o, o, o],
          [_, x, _],
        ])),
        GameState.oWin);
  });

  test('o win diagonal board', () {
    expect(
        getGameState(buildBoard([
          [o, x, _],
          [_, o, _],
          [_, x, o],
        ])),
        GameState.oWin);
  });

  test('o win anti-diagonal board', () {
    expect(
        getGameState(buildBoard([
          [x, x, o],
          [_, o, _],
          [o, x, x],
        ])),
        GameState.oWin);
  });

  test('cats board', () {
    expect(
        getGameState(buildBoard([
          [x, o, x],
          [x, x, o],
          [o, x, o],
        ])),
        GameState.cats);
  });
}

Board buildBoard(List<List<SquareState>> states) {
  return new Board.withSquares(states
      .map((row) => row.map((state) => new Square(state)).toList())
      .toList());
}
