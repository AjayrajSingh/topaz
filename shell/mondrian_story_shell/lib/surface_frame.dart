// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const Duration _scaleAnimationDuration = const Duration(seconds: 1);
const double _scaleMinScale = 0.6;
const Curve _scaleCurve = Curves.fastOutSlowIn;

/// Frame for child views
class SurfaceFrame extends StatelessWidget {
  /// Constructor
  const SurfaceFrame(
      {Key key, this.child, this.interactable = true, this.depth = 0.0})
      : assert(-1.0 <= depth && depth <= 1.0),
        super(key: key);

  /// The child
  final Widget child;

  /// If true then ChildView hit tests will go through
  final bool interactable;

  /// How much to scale this surface [-1.0, 1.0]
  /// Negative numbers increase elevation without scaling
  final double depth;

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            new AnimatedContainer(
              duration: _scaleAnimationDuration,
              curve: _scaleCurve,
              transform: _scale(constraints.biggest.center(Offset.zero)),
              child: new IgnorePointer(
                child: new PhysicalModel(
                  elevation: (1.0 - depth) * 125.0,
                  color: const Color(0x00000000),
                  child: child,
                ),
              ),
            ),
      );

  Matrix4 _scale(Offset center) {
    double scale =
        _scaleMinScale + (1.0 - depth.clamp(0.0, 1.0)) * (1.0 - _scaleMinScale);
    Matrix4 matrix = new Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(scale, scale)
      ..translate(-center.dx, -center.dy);
    return matrix;
  }
}
