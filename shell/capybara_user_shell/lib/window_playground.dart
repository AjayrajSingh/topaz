// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'window/window.dart';

/// Displays a set of windows.
class WindowPlaygroundWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new Overlay(
        initialEntries: <OverlayEntry>[
          new OverlayEntry(
            builder: (BuildContext context) => new Stack(children: <Widget>[
                  new Positioned(
                    left: 50.0,
                    top: 50.0,
                    child: new Container(
                      width: 500.0,
                      height: 200.0,
                      child: new Window(),
                    ),
                  ),
                  new Positioned(
                    left: 350.0,
                    top: 300.0,
                    child: new Container(
                      width: 500.0,
                      height: 200.0,
                      child: new Window(),
                    ),
                  ),
                ]),
          ),
        ],
      );
}
