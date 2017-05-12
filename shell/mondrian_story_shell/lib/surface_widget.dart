// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'model.dart';

/// Frame for child views
class SurfaceWidget extends StatelessWidget {
  /// If true then ChildView hit tests will go through
  final bool interactable;

  /// Whether or not to show border chrome
  final bool chrome;

  /// Constructor
  SurfaceWidget({Key key, this.interactable: true, this.chrome: true})
      : super(key: key);

  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<Surface>(
        child: new MondrianSpinner(),
        builder: (BuildContext context, Widget spinner, Surface surface) {
          Widget childView = surface.connection == null
              ? spinner
              : new ChildView(
                  connection: surface.connection,
                  hitTestable: interactable,
                );
          return chrome
              ? new Container(
                  margin: const EdgeInsets.all(2.0),
                  padding: const EdgeInsets.all(20.0),
                  color: const Color(0xFFFFFFFF),
                  child: childView,
                )
              : childView;
        },
      );
}
