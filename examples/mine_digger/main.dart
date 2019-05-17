// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Classic minesweeper-inspired game. The mouse controls are standard
// except for left + right combo which is not implemented. For touch,
// the duration of the pointer determines probing versus flagging.
//
// There are only 3 classes to understand. MineDiggerApp, which is
// contains all the logic and two classes that describe the mines:
// CoveredMineNode and ExposedMineNode, none of them holding state.

// Colors for each mine count (0-8):
const List<Color> textColors = <Color>[
  Color(0xFF555555),
  Color(0xFF0094FF), // blue
  Color(0xFF13A023), // green
  Color(0xFFDA1414), // red
  Color(0xFF1E2347), // black
  Color(0xFF7F0037), // dark red
  Color(0xFF000000),
  Color(0xFF000000),
  Color(0xFF000000),
];

final List<TextStyle> textStyles = textColors.map((Color color) {
  return TextStyle(color: color, fontWeight: FontWeight.bold);
}).toList();

enum CellState { covered, exploded, cleared, flagged, shown }

class MineDigger extends StatefulWidget {
  @override
  MineDiggerState createState() => MineDiggerState();
}

class MineDiggerState extends State<MineDigger> {
  static const int rows = 9;
  static const int cols = 9;
  static const int totalMineCount = 11;

  bool alive;
  bool hasWon;
  int detectedCount;
  Timer timer;
  Stopwatch gameTime = Stopwatch();

  // |cells| keeps track of the positions of the mines.
  List<List<bool>> cells;
  // |uiState| keeps track of the visible player progess.
  List<List<CellState>> uiState;

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void resetGame() {
    alive = true;
    hasWon = false;
    detectedCount = 0;
    gameTime.reset();

    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        setState((){
          // time blah blah
          });
      });

    // Initialize matrices.
    cells = List<List<bool>>.generate(rows, (int row) {
      return List<bool>.filled(cols, false);
    });
    uiState = List<List<CellState>>.generate(rows, (int row) {
      return List<CellState>.filled(cols, CellState.covered);
    });
    // Place the mines.
    Random random = Random();
    int minesRemaining = totalMineCount;
    while (minesRemaining > 0) {
      int pos = random.nextInt(rows * cols);
      int row = pos ~/ rows;
      int col = pos % cols;
      if (!cells[row][col]) {
        cells[row][col] = true;
        minesRemaining--;
      }
    }
  }

  PointerDownEventListener _pointerDownHandlerFor(int posX, int posY) {
    return (PointerDownEvent event) {
      if (event.buttons == 1) {
        probe(posX, posY);
      } else if (event.buttons == 2) {
        flag(posX, posY);
      }
    };
  }

  Widget buildBoard() {
    bool hasCoveredCell = false;
    List<Row> flexRows = <Row>[];
    for (int iy = 0; iy < rows; iy++) {
      List<Widget> row = <Widget>[];
      for (int ix = 0; ix < cols; ix++) {
        CellState state = uiState[iy][ix];
        int count = mineCount(ix, iy);
        if (!alive) {
          if (state != CellState.exploded)
            state = cells[iy][ix] ? CellState.shown : state;
        }
        if (state == CellState.covered || state == CellState.flagged) {
          row.add(GestureDetector(
            onTap: () {
              if (state == CellState.covered)
                probe(ix, iy);
            },
            onLongPress: () {
              // TODO(cpu): Add audio or haptic feedback.
              flag(ix, iy);
            },
            child: Listener(
              onPointerDown: _pointerDownHandlerFor(ix, iy),
              child: CoveredMineNode(
                flagged: state == CellState.flagged,
                posX: ix,
                posY: iy
              )
            )
          ));
          if (state == CellState.covered) {
            // Mutating |hasCoveredCell| here is hacky, but convenient, same
            // goes for mutating |hasWon| below.
            hasCoveredCell = true;
          }
        } else {
          row.add(ExposedMineNode(
            state: state,
            count: count
          ));
        }
      }
      flexRows.add(
        Row(
          children: row,
          mainAxisAlignment: MainAxisAlignment.center,
          key: ValueKey<int>(iy)
        )
      );
    }

    if (!hasCoveredCell) {
      // all cells uncovered. Are all mines flagged?
      if ((detectedCount == totalMineCount) && alive) {
        hasWon = true;
        gameTime.stop();
      }
    }

    return Container(
      padding: EdgeInsets.all(10.0),
      margin: EdgeInsets.all(10.0),
      color: Color(0xFF6B6B6B),
      child: Column(children: flexRows)
    );
  }

  Widget buildAppBar(BuildContext context) {
    String appBarCaption = hasWon ?
      'Awesome!!' : alive ?
        'Dig! Dig!   [found:$detectedCount  total:$totalMineCount]':
        'Kaboom! Try harder [press here]';

    int elapsed = gameTime.elapsedMilliseconds ~/ 1000;
    return AppBar(
      // FIXME: Strange to have the app bar be tapable.
      title: Listener(
        onPointerDown: handleAppBarPointerDown,
        child: Text(appBarCaption,
          style: Theme.of(context).primaryTextTheme.title)
      ),
      centerTitle: true,
      actions: <Widget>[
        Container(
          child: Text('$elapsed seconds'),
          color: Colors.teal,
          margin: EdgeInsets.all(14.0),
          padding: EdgeInsets.all(2.0))
        ]
    );
  }

  @override
  Widget build(BuildContext context) {
    // We build the board before we build the app bar because we compute the win state
    // during build step.
    Widget board = buildBoard();
    return MaterialApp(
      title: 'Mine Digger',
      home: Scaffold(
        appBar: buildAppBar(context),
        body: Container(
          child: Center(child: board),
          color: Colors.grey[50],
        ),
      ),
    );
  }

  void handleAppBarPointerDown(PointerDownEvent event) {
    setState(resetGame);
  }

  // User action. The user uncovers the cell which can cause losing the game.
  void probe(int x, int y) {
    if (!alive)
      return;

    if (uiState[y][x] == CellState.flagged)
      return;
    setState(() {
      // Allowed to probe.
      if (cells[y][x]) {
        // Probed on a mine --> dead!!
        uiState[y][x] = CellState.exploded;
        alive = false;
        timer.cancel();
      } else {
        // No mine, uncover nearby if possible.
        cull(x, y);
        // Start the timer if needed.
        if (!gameTime.isRunning)
          gameTime.start();
      }
    });
  }

  // User action. The user is sure a mine is at this location.
  void flag(int x, int y) {
    if (!alive)
      return;
    setState(() {
      if (uiState[y][x] == CellState.flagged) {
        uiState[y][x] = CellState.covered;
        --detectedCount;
      } else {
        uiState[y][x] = CellState.flagged;
        ++detectedCount;
      }
    });
  }

  // Recursively uncovers cells whose totalMineCount is zero.
  void cull(int x, int y) {
    if (!inBoard(x, y))
      return;
    if (uiState[y][x] == CellState.cleared)
      return;
    uiState[y][x] = CellState.cleared;

    if (mineCount(x, y) > 0)
      return;

    cull(x - 1, y);
    cull(x + 1, y);
    cull(x, y - 1);
    cull(x, y + 1 );
    cull(x - 1, y - 1);
    cull(x + 1, y + 1);
    cull(x + 1, y - 1);
    cull(x - 1, y + 1);
  }

  int mineCount(int x, int y) {
    int count = 0;
    count += bombs(x - 1, y);
    count += bombs(x + 1, y);
    count += bombs(x, y - 1);
    count += bombs(x, y + 1 );
    count += bombs(x - 1, y - 1);
    count += bombs(x + 1, y + 1);
    count += bombs(x + 1, y - 1);
    count += bombs(x - 1, y + 1);
    return count;
  }

  int bombs(int x, int y) => inBoard(x, y) && cells[y][x] ? 1 : 0;

  bool inBoard(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;
}

Widget buildCell(Widget child) {
  return Container(
    padding: EdgeInsets.all(1.0),
    height: 27.0, width: 27.0,
    color: Color(0xFFC0C0C0),
    margin: EdgeInsets.all(2.0),
    child: child
  );
}

Widget buildInnerCell(Widget child) {
  return Container(
    padding: EdgeInsets.all(1.0),
    margin: EdgeInsets.all(3.0),
    height: 17.0, width: 17.0,
    child: child
  );
}

class CoveredMineNode extends StatelessWidget {

  const CoveredMineNode({ this.flagged, this.posX, this.posY });

  final bool flagged;
  final int posX;
  final int posY;

  @override
  Widget build(BuildContext context) {
    Widget text;
    if (flagged) {
      text = buildInnerCell(RichText(
        text: TextSpan(
          text: 'm',    // TODO(cpu) this should be \u2691
          style: textStyles[5],
        ),
        textAlign: TextAlign.center,
      ));
    }

    Container inner = Container(
      margin: EdgeInsets.all(2.0),
      height: 17.0, width: 17.0,
      color: Color(0xFFD9D9D9),
      child: text,
    );

    return buildCell(inner);
  }
}

class ExposedMineNode extends StatelessWidget {

  const ExposedMineNode({ this.state, this.count });

  final CellState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget text;
    if (state == CellState.cleared) {
      // Uncovered cell with nearby mine count.
      if (count != 0) {
        text = RichText(
          text: TextSpan(
            text: '$count',
            style: textStyles[count],
          ),
          textAlign: TextAlign.center,
        );
      }
    } else {
      // Exploded mine or shown mine for 'game over'.
      int color = state == CellState.exploded ? 3 : 0;
      text = RichText(
        text: TextSpan(
          text: '*',   // TODO(cpu) this should be \u2600
          style: textStyles[color],
        ),
        textAlign: TextAlign.center,
      );
    }
    return buildCell(buildInnerCell(text));
  }
}

void main() {
  runApp(MineDigger());
}
