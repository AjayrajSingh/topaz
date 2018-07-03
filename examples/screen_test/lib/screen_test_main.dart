// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

const Color _lightColor = const Color(0xFF4dac26);
const Color _darkColor = const Color(0xFFd01c8b);
const int _gridSize = 6;

/// Display a checker board pattern in red and green to verify that the
/// screen is displaying properly.
class CheckerBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Size oneSize = new Size(size.width / _gridSize, size.height / _gridSize);
    List<Widget> rows = <Widget>[];
    for (int i = 0; i < _gridSize; i++) {
      List<Widget> boxes = <Widget>[];
      for (int j = 0; j < _gridSize; j++) {
        boxes.add(new Container(
          width: oneSize.width,
          height: oneSize.height,
          color: (i % 2) == (j % 2) ? _darkColor : _lightColor,
        ));
      }
      rows.add(new Row(
        children: boxes,
        mainAxisSize: MainAxisSize.max,
      ));
    }
    return new Column(
      mainAxisSize: MainAxisSize.max,
      children: rows,
    );
  }
}

void main() {
  runApp(new MaterialApp(
    home: new CheckerBoard(),
  ));
}
