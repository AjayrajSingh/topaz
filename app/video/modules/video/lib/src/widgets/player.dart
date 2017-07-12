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

  Widget _buildPlayerMode(VideoModuleModel model) {
    switch (model.displayMode) {
      case DisplayMode.remoteControl:
        return new RemoteControl(
          playLocal: model.playLocal,
          remoteDeviceName: model.getDisplayName(model.remoteDeviceName),
          asset: model.asset,
        );
      case DisplayMode.immersive:
        return new Center(
          child: _screen,
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
                  model.showControlOverlay ? _playControls : new Container(),
                ],
              ),
            ),
            new Scrubber(height: 2.0),
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
            // Scrubber for this Mode includes PlayControls
            new Scrubber(height: 2.0),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(builder: (
      BuildContext context,
      Widget child,
      VideoModuleModel model,
    ) {
      Size size = MediaQuery.of(context).size;
      if (size.width + size.height <= 912.0) {
        model.displayMode = DisplayMode.localSmall;
        model.notifyListeners();
      } else if (model.displayMode != DisplayMode.remoteControl &&
          model.displayMode != DisplayMode.immersive &&
          model.displayMode != DisplayMode.standby) {
        model.displayMode = DisplayMode.localLarge;
        model.notifyListeners();
      }
      return new Container(
        color: Colors.black,
        child: _buildPlayerMode(model),
      );
    });
  }
}
