// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'board_logic.dart';
import 'board_piece.dart';
import 'board_square.dart';

//final BoardGridDelegate _boardGridDelegate = new BoardGridDelegate();
final Color _kLightColor = new Color(0xFFE0E0E0);
final Color _kDarkColor = new Color(0xFFFAFAFA);

enum _Player { white, black }

/// Widget representing a chess board.
class Board extends StatefulWidget {
  /// Creates a new [Board].
  Board({Key key}) : super(key: key);

  @override
  _BoardState createState() => new _BoardState();
}

class _BoardState extends State<Board> {
  Map<String, dynamic> undo;
  List<int> highlights = <int>[];
  int pieceSelected;
  bool confirming = false;
  _Player player = _Player.black;
  _Player _turn = _Player.white;
  ChessGame chessGame;
  Map<int, BoardPiece> positions = <int, BoardPiece>{};

  @override
  void initState() {
    super.initState();
    chessGame = new ChessGame();
    // Proper Starting Positions
    positions = <int, BoardPiece>{
      0: new BoardPiece(0, 'R', movePiece, pieceInHand),
      1: new BoardPiece(1, 'N', movePiece, pieceInHand),
      2: new BoardPiece(2, 'B', movePiece, pieceInHand),
      3: new BoardPiece(3, 'Q', movePiece, pieceInHand),
      4: new BoardPiece(4, 'K', movePiece, pieceInHand),
      5: new BoardPiece(5, 'B', movePiece, pieceInHand),
      6: new BoardPiece(6, 'N', movePiece, pieceInHand),
      7: new BoardPiece(7, 'R', movePiece, pieceInHand),
      8: new BoardPiece(8, 'P', movePiece, pieceInHand),
      9: new BoardPiece(9, 'P', movePiece, pieceInHand),
      10: new BoardPiece(10, 'P', movePiece, pieceInHand),
      11: new BoardPiece(11, 'P', movePiece, pieceInHand),
      12: new BoardPiece(12, 'P', movePiece, pieceInHand),
      13: new BoardPiece(13, 'P', movePiece, pieceInHand),
      14: new BoardPiece(14, 'P', movePiece, pieceInHand),
      15: new BoardPiece(15, 'P', movePiece, pieceInHand),
      48: new BoardPiece(48, 'p', movePiece, pieceInHand),
      49: new BoardPiece(49, 'p', movePiece, pieceInHand),
      50: new BoardPiece(50, 'p', movePiece, pieceInHand),
      51: new BoardPiece(51, 'p', movePiece, pieceInHand),
      52: new BoardPiece(52, 'p', movePiece, pieceInHand),
      53: new BoardPiece(53, 'p', movePiece, pieceInHand),
      54: new BoardPiece(54, 'p', movePiece, pieceInHand),
      55: new BoardPiece(55, 'p', movePiece, pieceInHand),
      56: new BoardPiece(56, 'r', movePiece, pieceInHand),
      57: new BoardPiece(57, 'n', movePiece, pieceInHand),
      58: new BoardPiece(58, 'b', movePiece, pieceInHand),
      59: new BoardPiece(59, 'q', movePiece, pieceInHand),
      60: new BoardPiece(60, 'k', movePiece, pieceInHand),
      61: new BoardPiece(61, 'b', movePiece, pieceInHand),
      62: new BoardPiece(62, 'n', movePiece, pieceInHand),
      63: new BoardPiece(63, 'r', movePiece, pieceInHand)
    };
  }

  @override
  void dispose() {
    super.dispose();
  }

  void clickSquare(int index) {
    if (pieceSelected == null) {
      if (positions.containsKey(index)) {
        pieceSelected = index;
        setState(() {
          highlights = chessGame.validMoves(index);
        });
      }
    } else {
      if (highlights.contains(index)) {
        Map<String, int> move = <String, int>{
          'from': pieceSelected,
          'to': index,
        };
        movePiece(move);
        pieceSelected == null;
      } else if (positions.containsKey(index)) {
        pieceSelected = index;
        setState(() {
          highlights = chessGame.validMoves(index);
        });
      } else {
        pieceSelected = null;
        setState(() {
          highlights = <int>[];
        });
      }
    }
  }

  void pieceInHand(int index) {
    List<int> setOfMoves = chessGame.validMoves(index);
    setState(() {
      highlights = setOfMoves;
    });
  }

  void movePiece(Map<String, int> data) {
    int from = data['from'];
    int to = data['to'];
    List<int> setOfMoves = chessGame.validMoves(from);
    if (setOfMoves.contains(to)) {
      print('valid move');
      BoardPiece piece = positions[from];
      BoardPiece capture = positions[to];
      undo = <String, dynamic>{
        'piece': piece,
        'from': from,
        'to': to,
        'capture': capture,
      };
      setState(() {
        highlights = <int>[from, to];
        BoardPiece piece = positions[from];
        positions.remove(from);
        piece.index = to;
        positions[to] = piece;
      });
      confirmMove();
    } else {
      setState(() {
        highlights = <int>[];
      });
    }
  }

  void cancelMove() {
    confirming = false;
    print('cancelled');
    Navigator.pop(context);
    setState(() {
      highlights = <int>[];
      BoardPiece piece = undo['piece'];
      piece.index = undo['from'];
      BoardPiece capture = undo['capture'];
      if (capture != null) {
        capture.index = undo['to'];
        positions[undo['to']] = capture;
      }
      positions[undo['from']] = piece;
      positions.remove(undo['to']);
    });
  }

  void confirmed() {
    confirming = false;
    print('confirmed');
  }

  void confirmMove() {
    confirming = true;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    print(size);
    List<Widget> grids = <Widget>[];
    int index = 0;
    if (player == _Player.white) {
      for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
          Color colorval = (i % 2 == (j % 2)) ? _kDarkColor : _kLightColor;
          index = ((7 - i) * 8) + j;
          bool highlight = highlights.contains(index);
          grids.add(new BoardSquare(index, colorval, this.clickSquare,
              piece: this.positions[index], highlight: highlight));
        }
      }
    } else {
      for (int i = 7; i >= 0; i--) {
        for (int j = 7; j >= 0; j--) {
          Color colorval = (i % 2 == (j % 2)) ? _kDarkColor : _kLightColor;
          index = ((7 - i) * 8) + j;
          bool highlight = highlights.contains(index);
          grids.add(new BoardSquare(index, colorval, this.clickSquare,
              piece: this.positions[index], highlight: highlight));
        }
      }
    }
    print('turn: $_turn');
    String turntext = _turn.toString().split('.')[1];
    turntext = turntext[0].toUpperCase() + turntext.substring(1);

    return new Scaffold(
        appBar: new AppBar(title: new Text('$turntext To Move')),
        body: new Container(
            child: new Center(
                child: new Container(
                    constraints: new BoxConstraints(
                        minHeight: min(size.height, size.width) * 0.9,
                        maxHeight: min(size.height, size.width) * 0.9,
                        minWidth: min(size.height, size.width) * 0.9,
                        maxWidth: min(size.height, size.width) * 0.9),
                    child: new GridView.count(
                      crossAxisCount: 8,
                      children: grids,
                    )))));
  }
}
