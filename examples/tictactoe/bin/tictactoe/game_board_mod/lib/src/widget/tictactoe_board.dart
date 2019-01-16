// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:tictactoe_common/common.dart' show GameState;

import '../model/tictactoe_model.dart';

import 'square.dart';

class TicTacToeBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(50.0),
      child: new Stack(
        children: <Widget>[_getPlaySurface(), _getWinBoard()],
      ),
    );
  }

  Widget _getWinBoard() {
    return new ScopedModelDescendant<TicTacToeModel>(
      builder: (context, child, model) => new Offstage(
            child: new GestureDetector(
              child: new Center(
                child: new PhysicalModel(
                  color: Colors.lightBlue,
                  borderRadius: new BorderRadius.circular(16.0),
                  child: new Column(
                    children: <Widget>[
                      new Text(
                        model.gameState == GameState.cats
                            ? 'Cats'
                            : model.gameState == GameState.xWin
                                ? 'X wins'
                                : 'O wins',
                        style: new TextStyle(fontSize: 100.0),
                      ),
                      new Text(
                        'Tap to play again',
                        style: new TextStyle(fontSize: 50.0),
                      ),
                    ],
                  ),
                ),
              ),
              onTap: () => model.restartGame(),
            ),
            offstage: model.gameState == GameState.inProgress,
          ),
    );
  }

  Widget _getPlaySurface() {
    return new Column(
      children: new List.generate(
        3,
        (row) => new Expanded(
              child: new Row(
                children: new List.generate(
                  3,
                  (column) => new Square(row, column),
                ),
              ),
            ),
      ),
    );
  }
}
