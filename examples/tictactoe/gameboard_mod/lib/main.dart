import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets/modular.dart';

import 'src/model/tictactoe_model.dart';
import 'src/widget/tictactoe_board.dart';

void main() {
  setupLogger(name: 'tictactoe gameboard');
  new ModuleDriver().start().then((_) => trace('module is ready'));

  runApp(
    MaterialApp(
      home: Material(
        child: ScopedModel<TicTacToeModel>(
          model: new TicTacToeModel(),
          child: new TicTacToeBoard(),
        ),
      ),
    ),
  );
}
