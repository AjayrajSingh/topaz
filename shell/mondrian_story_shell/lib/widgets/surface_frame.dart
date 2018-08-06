// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../models/depth_model.dart';

const Duration _scaleAnimationDuration = const Duration(seconds: 1);
const double _scaleMinScale = 0.6;
const double _scaleMaxScale = 1.0;
const double _surfaceDepth = 250.0;
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
  Widget build(BuildContext context) {
    double scale = lerpDouble(
      _scaleMinScale,
      _scaleMaxScale,
      (1.0 - depth.clamp(0.0, 1.0)),
    );
    Matrix4 transform = new Matrix4.identity()..scale(scale, scale);

    return new AnimatedContainer(
      duration: _scaleAnimationDuration,
      curve: _scaleCurve,
      alignment: FractionalOffset.center,
      transform: transform,
      child: new IgnorePointer(
        child: new ScopedModelDescendant<DepthModel>(
          builder: (
            BuildContext context,
            Widget child,
            DepthModel depthModel,
          ) {
            double elevation = lerpDouble(
              0.0,
              _surfaceDepth,
              (depthModel.maxDepth - depth) / 2.0,
            ).clamp(0.0, _surfaceDepth);

            return new PhysicalModel(
              elevation: elevation,
              color: const Color(0x00000000),
              child: child,
            );
          },
          child: child,
        ),
      ),
    );
  }
}
