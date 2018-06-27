import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lib.widgets/modular.dart';

import '../lib/src/model/tictactoe_model.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/widget/square.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/widget/tictactoe_board.dart'; // ignore: avoid_relative_lib_imports

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
