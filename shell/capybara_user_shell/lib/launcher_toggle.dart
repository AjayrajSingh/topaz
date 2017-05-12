// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// A toggle button for the launcher.
class LauncherToggleWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new RepaintBoundary(
        child: new AspectRatio(
          aspectRatio: 1.0,
          child: new CustomPaint(
            painter: new _Painter(),
          ),
        ),
      );
}

class _Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(8.0, size.shortestSide / 2);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      new Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      size.center(Offset.zero),
      max(radius - 2.0, 0.0),
      new Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) {
    return false;
  }
}
