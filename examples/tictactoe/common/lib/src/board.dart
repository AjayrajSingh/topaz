// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'square.dart';

class Board {
  final List<List<Square>> _board;

  Board()
      : _board = new List.unmodifiable(new List.generate(3,
            (_) => new List.generate(3, (_) => new Square(SquareState.empty))));

  Board.withSquares(List<List<Square>> squares)
      : _board = new List.unmodifiable(new List.generate(
            3,
            (row) => new List.unmodifiable(
                new List.generate(3, (column) => squares[row][column]))));

  int get xCount {
    return _board
        .map((row) =>
            row.where((square) => square.state == SquareState.x).length)
        .fold(0, (partialSum, rowValue) => partialSum + rowValue);
  }

  int get oCount {
    return _board
        .map((row) =>
            row.where((square) => square.state == SquareState.o).length)
        .fold(0, (partialSum, rowValue) => partialSum + rowValue);
  }

  Square getSquare(int row, int column) {
    return _board[row][column];
  }

  /// Get row from board where [row] index is between 0 and 2 inclusive.
  Iterable<Square> getRow(int row) {
    assert(row >= 0 && row <= 2);
    return new List.unmodifiable(_board[row]);
  }

  /// Get column from board where [column] index is between 0 and 2 inclusive.
  Iterable<Square> getColumn(int column) {
    assert(column >= 0 && column <= 2);
    return new List.unmodifiable(
        [_board[0][column], _board[1][column], _board[2][column]]);
  }

  /// Get diagonal starting from top-left corner.
  Iterable<Square> getDiagonal() {
    return new List.unmodifiable([_board[0][0], _board[1][1], _board[2][2]]);
  }

  /// Get diagonal starting from top-right corner.
  Iterable<Square> getAntiDiagonal() {
    return new List.unmodifiable([_board[2][0], _board[1][1], _board[0][2]]);
  }

  Iterable<Square> getEmptySquares() {
    return _board
        .map((row) => row.where((square) => square.state == SquareState.empty))
        .fold<List<Square>>(
            [],
            (List<Square> empties, Iterable<Square> rowEmpties) =>
                empties..addAll(rowEmpties));
  }
}
