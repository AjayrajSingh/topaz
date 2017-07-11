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
            new Scrubber(),
          ],
        );
      case DisplayMode.localLarge:
      default:
        // This is in a Stack to fake the appearance of the Slider directly
        // below the video, while still allowing the Slider to have ample space
        // above AND below, to be tapped on
        return new Stack(
          children: <Widget>[
            new Column(
              children: <Widget>[
                _deviceChooser,
                new Expanded(
                  child: _screen,
                ),
                new AnimatedCrossFade(
                    duration: kAnimationTime,
                    firstChild: new Padding(
                      // height of play controls + Slider._kReactionRadius
                      padding: new EdgeInsets.only(bottom: 76.0),
                    ),
                    secondChild: new Container(),
                    crossFadeState: model.showControlOverlay
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond)
              ],
            ),
            // Scrubber for this Mode includes PlayControls
            new Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: new Scrubber(),
            ),
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
