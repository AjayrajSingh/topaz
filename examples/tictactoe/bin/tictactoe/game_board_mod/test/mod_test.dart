import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lib.widgets/model.dart';
import 'package:topaz.examples.tictactoe.bin.tictactoe.game_board_mod._tictactoe_game_board_mod_dart_library/src/model/tictactoe_model.dart'; // ignore: implementation_imports
import 'package:topaz.examples.tictactoe.bin.tictactoe.game_board_mod._tictactoe_game_board_mod_dart_library/src/widget/square.dart'; // ignore: implementation_imports
import 'package:topaz.examples.tictactoe.bin.tictactoe.game_board_mod._tictactoe_game_board_mod_dart_library/src/widget/tictactoe_board.dart'; // ignore: implementation_imports

void main() {
  testWidgets('x in middle', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(1, 1);

    expect(gameTester.getSquareValue(1, 1), 'X');
    expect(gameTester.getSquareValue(0, 1), ' ');
  });

  testWidgets('x and o played', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(1, 0);

    expect(gameTester.getSquareValue(1, 1), 'X');
    expect(gameTester.getSquareValue(1, 0), 'O');
    expect(gameTester.getSquareValue(0, 1), ' ');
  });

  testWidgets('square played twice', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(1, 1);

    expect(gameTester.getSquareValue(1, 1), 'X');
  });

  testWidgets('x wins', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(2, 0);
    await gameTester.tapSquare(2, 2);

    gameTester.checkForGameResult('X wins');
  });

  testWidgets('o wins', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(1, 2);
    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(2, 0);
    await gameTester.tapSquare(2, 2);

    gameTester.checkForGameResult('O wins');
  });

  testWidgets('cats game', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(0, 1);
    await gameTester.tapSquare(2, 1);
    await gameTester.tapSquare(1, 2);
    await gameTester.tapSquare(1, 0);
    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(2, 2);
    await gameTester.tapSquare(2, 0);

    gameTester.checkForGameResult('Cats');
  });

  testWidgets("can't play after game done", (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(2, 0);
    await gameTester.tapSquare(2, 2);
    await gameTester.tapSquare(2, 1);

    expect(gameTester.getSquareValue(2, 1), ' ');
  });

  testWidgets('x wins then o wins', (WidgetTester tester) async {
    GameTester gameTester = await GameTester.startGame(tester);

    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(2, 0);
    await gameTester.tapSquare(2, 2);

    gameTester.checkForGameResult('X wins');

    await gameTester.tapOnPlayAgain();

    await gameTester.tapSquare(0, 2);
    await gameTester.tapSquare(0, 0);
    await gameTester.tapSquare(2, 0);
    await gameTester.tapSquare(1, 1);
    await gameTester.tapSquare(0, 1);
    await gameTester.tapSquare(2, 2);

    gameTester.checkForGameResult('O wins');
  });
}

class GameTester {
  WidgetTester widgetTester;
  Widget gameBoard;

  GameTester._(this.widgetTester, this.gameBoard);

  static Future<GameTester> startGame(WidgetTester widgetTester) async {
    TicTacToeModel tacToeModel = new TicTacToeModel();
    Widget testWidget = new MaterialApp(
      home: new Material(
        child: new ScopedModel<TicTacToeModel>(
          model: tacToeModel,
          child: new TicTacToeBoard(),
        ),
      ),
    );
    await widgetTester.pumpWidget(testWidget);
    return new GameTester._(widgetTester, testWidget);
  }

  Future<Null> tapOnPlayAgain() async {
    await widgetTester.tap(find.text('Tap to play again'));
    await widgetTester.pumpWidget(gameBoard);
    return null;
  }

  Future<Null> tapSquare(int row, int column) async {
    await widgetTester.tap(find.descendant(
        of: new SquareFinder(row, column),
        matching: find.byType(GestureDetector)));
    await widgetTester.pumpWidget(gameBoard);
    return null;
  }

  String getSquareValue(int row, int column) {
    Text text = find
        .descendant(
            of: new SquareFinder(row, column), matching: find.byType(Text))
        .evaluate()
        .first
        .widget;
    return text.data;
  }
  
  void checkForGameResult(String result) {
    expect(find.text(result), findsOneWidget);
  }
}

class SquareFinder extends MatchFinder {
  int row;
  int column;

  SquareFinder(this.row, this.column);

  @override
  String get description => 'Find square for row $row and column $column';

  @override
  bool matches(Element candidate) {
    Widget widget = candidate.widget;
    if (!(widget is Square)) {
      return false;
    }
    Square square = widget;
    return square.row == row && square.column == column;
  }
}
