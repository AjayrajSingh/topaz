// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.ui.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'surface.dart';

/// Frame for child views
class MondrianChildView extends StatelessWidget {
  /// Constructor
  const MondrianChildView({this.surface, this.interactable = true});

  /// If true then ChildView hit tests will go through
  final bool interactable;

  final Surface surface;

  @override
  Widget build(BuildContext context) => new AnimatedBuilder(
        animation: surface,
        builder: (BuildContext context, Widget child) =>
            surface.connection == null
                ? new Container(color: Colors.grey[300])
                : new ChildView(
                    connection: surface.connection,
                    hitTestable: interactable,
                  ),
      );
}
