// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';

const Color _lightColor = Color(0xFF4dac26);
const Color _darkColor = Color(0xFFd01c8b);
const int _gridSize = 6;

/// Display a checker board pattern in red and green to verify that the
/// screen is displaying properly.
class CheckerBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Size oneSize = Size(size.width / _gridSize, size.height / _gridSize);
    List<Widget> rows = <Widget>[];
    for (int i = 0; i < _gridSize; i++) {
      List<Widget> boxes = <Widget>[];
      for (int j = 0; j < _gridSize; j++) {
        boxes.add(Container(
          width: oneSize.width,
          height: oneSize.height,
          color: (i % 2) == (j % 2) ? _darkColor : _lightColor,
        ));
      }
      rows.add(Row(
        children: boxes,
        mainAxisSize: MainAxisSize.max,
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: rows,
    );
  }
}

void main() {
  setupLogger(
    name: 'flutter_screencap_test_app',
  );
  log.info('starting flutter_screencap_test_app');
  runApp(MaterialApp(
    home: CheckerBoard(),
  ));
}
