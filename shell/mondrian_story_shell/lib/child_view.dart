// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.ui.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const Duration _fadeAnimationDuration = const Duration(seconds: 1);
const double _fadeToScaleRatio = 0.2;
const double _fadeMinScale = 0.6;
const Curve _fadeCurve = Curves.fastOutSlowIn;

/// Frame for child views
class MondrianChildView extends StatelessWidget {
  /// Constructor
  MondrianChildView(
      {Key key, this.connection, this.interactable: true, this.fade: 0.0})
      : super(key: key) {
    assert(0.0 <= fade && fade <= 1.0);
  }

  /// The connection for this view
  final ChildViewConnection connection;

  /// If true then ChildView hit tests will go through
  final bool interactable;

  /// How much to fade this surface [0.0, 1.0]
  final double fade;

  @override
  Widget build(BuildContext context) => new AnimatedOpacity(
        duration: _fadeAnimationDuration,
        opacity: 1.0 - fade,
        curve: _fadeCurve,
        child: connection == null
            ? null
            : new ChildView(
                connection: connection,
                hitTestable: interactable,
              ),
      );
}
