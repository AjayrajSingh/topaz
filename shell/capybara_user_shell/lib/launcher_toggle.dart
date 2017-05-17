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
class LauncherToggleState extends State<LauncherToggleWidget>
    with TickerProviderStateMixin {
  bool _toggled = false;

  AnimationController _controller;
  Animation<double> _animation;

  final Tween<double> _backgroundOpacityTween =
      new Tween<double>(begin: 0.0, end: 0.33);

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    _animation = new CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
      reverseCurve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => new RepaintBoundary(
        child: new GestureDetector(
          onTap: () {
            setState(() {
              toggled = !_toggled;
              widget._callback?.call(_toggled);
            });
          },
          behavior: HitTestBehavior.opaque,
          child: new AspectRatio(
            aspectRatio: 1.0,
            child: new AnimatedBuilder(
              animation: _animation,
              builder: (BuildContext context, Widget child) => new CustomPaint(
                    painter: new _Painter(
                      _backgroundOpacityTween.evaluate(_animation),
                    ),
                  ),
            ),
          ),
        ),
      );

  /// Sets the toggle state.
  set toggled(bool value) {
    if (value == _toggled) {
      return;
    }
    setState(() {
      _toggled = value;
      _toggled ? _controller.forward() : _controller.reverse();
    });
  }
}

class _Painter extends CustomPainter {
  final double _backgroundOpacity;

  _Painter(this._backgroundOpacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (_backgroundOpacity > 0) {
      canvas.drawCircle(
        size.center(Offset.zero),
        max(size.shortestSide / 2 - 10.0, 0.0),
        new Paint()..color = Colors.grey.withOpacity(_backgroundOpacity),
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
    return _backgroundOpacity != oldDelegate._backgroundOpacity;
  }
}
