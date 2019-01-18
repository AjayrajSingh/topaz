// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:tictactoe_common/common.dart' show SquareState;

import '../model/tictactoe_model.dart';

@immutable
class Square extends StatelessWidget {
  final int row, column;

  const Square(this.row, this.column);

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<TicTacToeModel>(
      builder: (context, child, model) {
        return new Expanded(
          child: new GestureDetector(
            child: new Container(
              decoration: new BoxDecoration(
                border: new Border(
                  left: column == 1 ? new BorderSide() : BorderSide.none,
                  right: column == 1 ? new BorderSide() : BorderSide.none,
                  top: row == 1 ? new BorderSide() : BorderSide.none,
                  bottom: row == 1 ? new BorderSide() : BorderSide.none,
                ),
              ),
              child: new Center(
                child: new Text(
                  model.getSquareState(row, column) == SquareState.empty
                      ? ' '
                      : model.getSquareState(row, column) == SquareState.x
                          ? 'X'
                          : 'O',
                  style: new TextStyle(fontSize: 60.0),
                ),
              ),
            ),
            onTap: () => model.playSquare(row, column),
          ),
        );
      },
    );
  }
}
