// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// A class representing a board piece
class BoardPiece extends StatelessWidget {
  /// The index at which the board piece located
  int index;

  /// Name of the piece represented as a single character (one of "RNBQKPrnbqkp")
  String name;

  /// Image of the piece
  Image piece;

  /// Board piece opacity
  double opacity = 1.0;

  /// The previous position of this piece (to be used in undo logic)
  int from;

  /// Indicates whether this piece is selected
  bool selected = false;

  /// Callback to be called when this piece has been moved
  final ValueChanged<Map<String, dynamic>> onMove;

  /// Callback to be called when this piece is being dragged
  final ValueChanged<int> onDragStart;

  /// Creates a new [BoardPiece].
  BoardPiece(
    this.index,
    this.name,
    this.onMove,
    this.onDragStart, {
    Key key,
  })
      : super(key: key) {
    String filename;
    if (name.toUpperCase() == name) {
      filename = 'w${name.toUpperCase()}';
    } else {
      filename = 'b${name.toUpperCase()}';
    }
    this.piece = new Image.asset('assets/$filename.png');
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double height = (min(size.height, size.width) * 0.9) / 8;
//    GridSpecification gspec = _boardGridDelegate.getGridSpecification(
//        new BoxConstraints.loose(screenSize), 64);
//    double height = gspec.gridSize.height / gspec.rowCount;

    return new Draggable<BoardPiece>(
        data: this,
        child: piece,
        //childWhenDragging: new Opacity(opacity: 0.0, child: piece),
        childWhenDragging: new Container(
            child: null,
            decoration:
                new BoxDecoration(backgroundColor: Theme.of(context).accentColor
//                border: new Border.all(
//                    color: Colors.cyan[400],
//                    width: 2.0,
//                    ),
                    )),
        feedback: new Image(image: this.piece.image, height: height),
        maxSimultaneousDrags: 1,
        onDragStarted: () {
          onDragStart(this.index);
        },
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          onDragStart(null);
        }
//        onDragStarted: (){
//          from = index;
//          callback({'name': name, 'from': index, 'to' : 64});
//        },
//        onDraggableCanceled: (Velocity velocity, Offset offset) {
//          print(index);
//          callback({'name': name, 'from': 64, 'to' : from});
//        },
        );
  }
}
