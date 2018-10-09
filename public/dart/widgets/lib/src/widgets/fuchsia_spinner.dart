// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _kDefaultColor = Colors.blue;

const double _kInitialFractionalDiameter = 1.0 / 1.2;
const double _kTargetFractionalDiameter = 1.0;
const double _kRotationRadians = 6 * math.pi;
const Curve _kDefaultCurve = const Cubic(0.3, 0.1, 0.3, 0.9);

const Duration _kAnimationDuration = const Duration(seconds: 2);

/// The spinner used by fuchsia flutter apps.
class FuchsiaSpinner extends StatefulWidget {
  /// The color of the spinner at rest
  final Color color;

  /// Constructor.
  const FuchsiaSpinner({
    this.color = _kDefaultColor,
  });

  @override
  _FuchsiaSpinnerState createState() => new _FuchsiaSpinnerState();
}

class _FuchsiaSpinnerState extends State<FuchsiaSpinner>
    with SingleTickerProviderStateMixin {
  final Tween<double> _fractionalWidthTween = new Tween<double>(
    begin: _kInitialFractionalDiameter,
    end: _kTargetFractionalDiameter,
  );
  final Tween<double> _fractionalHeightTween = new Tween<double>(
    begin: _kInitialFractionalDiameter,
    end: _kInitialFractionalDiameter * 2 / 3,
  );

  final Curve _firstHalfCurve = const Cubic(0.75, 0.25, 0.25, 1.0);
  final Curve _secondHalfCurve = _kDefaultCurve;

  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(
      vsync: this,
      duration: _kAnimationDuration,
    )..repeat(period: _kAnimationDuration);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (_, BoxConstraints constraints) {
          double maxDiameter = math.min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return new AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              double tweenProgress = _tweenValue;
              double width = maxDiameter *
                  _fractionalWidthTween.transform(
                    tweenProgress,
                  );
              double height = maxDiameter *
                  _fractionalHeightTween.transform(
                    tweenProgress,
                  );
              return new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.rotationZ(
                  _kDefaultCurve.transform(_controller.value) *
                      _kRotationRadians,
                ),
                child: new Center(
                  child: new Container(
                    width: width,
                    height: height,
                    child: new Material(
                      elevation: tweenProgress * 10.0,
                      color: Color.lerp(
                        widget.color.withOpacity(0.8),
                        widget.color,
                        tweenProgress,
                      ),
                      borderRadius: new BorderRadius.circular(width / 2),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

  double get _tweenValue {
    if (_controller.value <= 0.5) {
      return _firstHalfCurve.transform(_controller.value / 0.5);
    } else {
      return 1.0 - _secondHalfCurve.transform((_controller.value - 0.5) / 0.5);
    }
  }
}
