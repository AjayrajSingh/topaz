// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'square.dart';

class Board {
  final List<Square> _board;

  Board.withSquares(List<Square> squares)
      : _board = new List<Square>.unmodifiable(squares).toList();

  /// Get row from board where [row] index is between 0 and 2 inclusive.
  Iterable<Square> getRow(int row) {
    assert(row >= 0 && row <= 2);
    return _board.sublist(3 * row, 3 * (row + 1));
  }

  /// Get column from board where [column] index is between 0 and 2 inclusive.
  Iterable<Square> getColumn(int column) {
    assert(column >= 0 && column <= 2);
    return [_board[column], _board[column + 3], _board[column + 6]];
  }

  /// Get diagonal starting from top-left corner.
  Iterable<Square> getDiagonal() {
    return [_board[0], _board[4], _board[8]];
  }

  /// Get diagonal starting from top-right corner.
  Iterable<Square> getAntiDiagonal() {
    return [_board[2], _board[4], _board[6]];
  }

  Iterable<Square> getEmptySquares() {
    return _board.where((s) => s.state == SquareState.empty);
  }
}