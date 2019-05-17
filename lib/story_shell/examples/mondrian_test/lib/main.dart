// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';

void main() {
  setupLogger(name: 'mondrianTest');

  Color randomColor =
      Color(0xFF000000 + math.Random().nextInt(0xFFFFFF));

  runApp(MaterialApp(
    title: 'Mondrian Test',
    home: Container(
      color: randomColor,
    ),
    theme: ThemeData(canvasColor: randomColor),
  ));
}
