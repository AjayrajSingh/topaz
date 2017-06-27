// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';
import '../widgets.dart';

/// Video player layout
class Player extends StatelessWidget {
  /// Constructor for the video player layout
  Player({
    Key key,
  })
      : super(key: key);

  final Widget _deviceChooser = new DeviceChooser();

  final Widget _screen = new Screen();

  final Widget _playControls = new PlayControls(
    primaryIconSize: 80.0,
    secondaryIconSize: 64.0,
    padding: 0.0,
  );

  final Widget _scrubber = new ScopedModelDescendant<VideoModuleModel>(
    builder: (
      BuildContext context,
      Widget child,
      VideoModuleModel model,
    ) {
      return new Scrubber(
          height: model.displayMode == DisplayMode.immersive ? 8.0 : 2.0);
    },
  );

  Widget _buildPlayerMode(VideoModuleModel model) {
    switch (model.displayMode) {
      case DisplayMode.remoteControl:
        return new RemoteControl(
          playLocal: model.playLocal,
          remoteDeviceName: model.remoteDeviceName,
          asset: model.asset,
        );
      case DisplayMode.immersive:
        return new Column(
          children: <Widget>[
            new Expanded(
              child: _screen,
            ),
            _scrubber,
          ],
        );
      case DisplayMode.standby:
        return new Standby(
          castingDeviceName: model.castingDeviceName,
          asset: model.asset,
        );
      case DisplayMode.localSmall:
        return new Column(
          children: <Widget>[
            _deviceChooser,
            new Expanded(
              child: new Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  _screen,
                  _playControls,
                ],
              ),
            ),
            _scrubber,
          ],
        );
      case DisplayMode.localLarge:
      default:
        return new Column(
          children: <Widget>[
            _deviceChooser,
            new Expanded(
              child: _screen,
            ),
            // Scrubber includes PlayControls
            _scrubber,
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO(maryxia) SO-477 optimize aspect ratio
    return new ScopedModelDescendant<VideoModuleModel>(builder: (
      BuildContext context,
      Widget child,
      VideoModuleModel model,
    ) {
      Size size = MediaQuery.of(context).size;
      if (size.width <= 640.0 && size.height <= 360.0) {
        model.displayMode = DisplayMode.localSmall;
      } else if (model.displayMode != DisplayMode.remoteControl &&
          model.displayMode != DisplayMode.immersive &&
          model.displayMode != DisplayMode.standby) {
        model.displayMode = DisplayMode.localLarge;
      }
      return new Container(
        color: Colors.black,
        child: _buildPlayerMode(model),
      );
    });
  }
}
