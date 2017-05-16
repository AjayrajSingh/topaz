// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// A toggle button for the launcher.
class LauncherToggleWidget extends StatefulWidget {
  final ValueChanged<bool> _callback;

  /// Constructor.
  LauncherToggleWidget({Key key, ValueChanged<bool> callback})
      : _callback = callback,
        super(key: key);

  @override
  LauncherToggleState createState() => new LauncherToggleState();
}

/// Manages the state of a [LauncherToggleWidget].
class LauncherToggleState extends State<LauncherToggleWidget> {
  bool _toggled = false;

  @override
  Widget build(BuildContext context) => new RepaintBoundary(
        child: new GestureDetector(
          onTap: () {
            setState(() {
              _toggled = !_toggled;
              widget._callback?.call(_toggled);
            });
          },
          behavior: HitTestBehavior.opaque,
          child: new AspectRatio(
            aspectRatio: 1.0,
            child: new CustomPaint(
              painter: new _Painter(_toggled),
            ),
          ),
        ),
      );

  /// Deactivates the toggle.
  set toggled(bool value) {
    setState(() => _toggled = value);
  }
}

class _Painter extends CustomPainter {
  final bool _withBackground;

  _Painter(this._withBackground);

  @override
  void paint(Canvas canvas, Size size) {
    if (_withBackground) {
      canvas.drawCircle(
        size.center(Offset.zero),
        max(size.shortestSide / 2 - 10.0, 0.0),
        new Paint()..color = Colors.grey.withOpacity(0.33),
      );
    }
    canvas.drawArc(
        new Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: min(8.0, size.shortestSide / 2),
        ),
        0.0,
        2 * PI,
        false,
        new Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) {
    return _withBackground != oldDelegate._withBackground;
  }
}
