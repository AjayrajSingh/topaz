// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';

void main() {
  setupLogger(name: 'mondrianTest');

  Color randomColor =
      new Color(0xFF000000 + new math.Random().nextInt(0xFFFFFF));

  runApp(new MaterialApp(
    title: 'Mondrian Test',
    home: new Container(
      color: randomColor,
    ),
    theme: new ThemeData(canvasColor: randomColor),
  ));
}
