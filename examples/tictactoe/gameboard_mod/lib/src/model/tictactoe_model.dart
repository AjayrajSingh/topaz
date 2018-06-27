import 'package:lib.widgets/model.dart';
import 'package:tictactoe_common/common.dart';

class TicTacToeModel extends Model {
  Game _game = new Game();
  GameState gameState = GameState.inProgress;

  /// Both row and column should be between 0 and 2 inclusive.
  SquareState getSquareState(int row, int column) {
    return _game.board.getSquare(row, column).state;
  }

  /// Both row and column should be between 0 and 2 inclusive.
  void playSquare(int row, int column) {
    if (getSquareState(row, column) != SquareState.empty ||
        gameState != GameState.inProgress) {
      return;
    }
    gameState = _game.playTurn(_game.board.getSquare(row, column));
    notifyListeners();
  }

  void restartGame() {
    _game = new Game();
    gameState = GameState.inProgress;
    notifyListeners();
  }
}
