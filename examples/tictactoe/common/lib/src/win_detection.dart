import 'board.dart';
import 'game.dart';
import 'square.dart';

GameState getGameState(Board board) {
  if (isWin(board, SquareState.x)) {
    return GameState.xWin;
  } else if (isWin(board, SquareState.o)) {
    return GameState.oWin;
  } else if (isCats(board)) {
    return GameState.cats;
  } else {
    return GameState.inProgress;
  }
}

/// Returns true iff there are no empty squares and game is tied.
bool isCats(Board board) {
  return board.getEmptySquares().isEmpty;
}

/// Returns true iff there are three squares in a row, column, or diagonal with
/// state [state].
bool isWin(Board board, SquareState state) {
  bool isOfType(Square s) => s.state == state;
  for (int i = 0; i < 3; i++) {
    if (board.getRow(i).every(isOfType) ||
        board.getColumn(i).every(isOfType)) {
      return true;
    }
  }
  return board.getDiagonal().every(isOfType) ||
      board.getAntiDiagonal().every(isOfType);
}