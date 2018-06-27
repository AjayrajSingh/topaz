import 'package:flutter/material.dart';

import 'square.dart';

class TicTacToeBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: new EdgeInsets.all(50.0),
      child: new Column(
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
      ),
    );
  }
}
