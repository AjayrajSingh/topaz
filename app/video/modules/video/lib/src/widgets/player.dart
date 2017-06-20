// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';
import '../widgets.dart';

/// The screen to video player.
class Player extends StatelessWidget {
  /// The screen for video player
  Player({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget deviceChooser = new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return new DeviceChooser();
      },
    );

    Widget screen = new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return new Screen();
      },
    );

    Widget playControls = new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return new PlayControls();
      },
    );
    Widget scrubber = new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return new Scrubber();
      },
    );

    // TODO(maryxia) SO-477 optimize aspect ratio
    return new ScopedModelDescendant<VideoModuleModel>(builder: (
      BuildContext context,
      Widget child,
      VideoModuleModel model,
    ) {
      return new Container(
        color: Colors.black,
        child: new Column(
          children: <Widget>[
            deviceChooser,
            new Expanded(
              child: new Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  screen,
                  playControls,
                ],
              ),
            ),
            scrubber,
          ],
        ),
      );
    });
  }
}
