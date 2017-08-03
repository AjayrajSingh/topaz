// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/player_model.dart';
import '../modular/video_module_model.dart';
import '../widgets.dart';

/// Video player layout
class Player extends StatelessWidget {
  /// Constructor for the video player layout
  Player({
    Key key,
  })
      : super(key: key);

  final Widget _screen = new Screen();

  final Widget _playControls = new PlayControls(
    primaryIconSize: 80.0,
    secondaryIconSize: 64.0,
    padding: 0.0,
  );

  Widget _buildRetry(VideoModuleModel moduleModel, PlayerModel playerModel) {
    return new AnimatedCrossFade(
      duration: kPlayControlsAnimationTime,
      firstChild: new Center(
        child: new Container(
          decoration: new BoxDecoration(
            borderRadius: new BorderRadius.circular(3.0),
            color: Colors.black,
          ),
          padding: new EdgeInsets.all(16.0),
          child: new Row(
            children: <Widget>[
              new Text(
                'UNABLE TO CAST',
                style: new TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[50],
                  letterSpacing: 0.02,
                ),
              ),
              new GestureDetector(
                onTap: () =>
                    playerModel.playRemote(moduleModel.remoteDeviceName),
                child: new Padding(
                  padding: new EdgeInsets.only(left: 32.0),
                  child: new Text(
                    'RETRY',
                    style: new TextStyle(
                      fontSize: 14.0,
                      color: Colors.blue,
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      secondChild: new Container(),
      crossFadeState: playerModel.failedCast
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
    );
  }

  Widget _buildPlayerMode(
      VideoModuleModel moduleModel, PlayerModel playerModel, bool smallScreen) {
    Widget _deviceChooser = new DeviceChooser(
      playRemote: playerModel.playRemote,
    );
    switch (moduleModel.getDisplayMode()) {
      case DisplayMode.remoteControl:
        return new RemoteControl(
          playLocal: playerModel.playLocal,
          remoteDeviceName:
              moduleModel.getDisplayName(moduleModel.remoteDeviceName),
          asset: playerModel.asset,
          smallScreen: smallScreen,
        );
      case DisplayMode.immersive:
        return new Center(
          child: _screen,
        );
      case DisplayMode.standby:
        return new Standby(
          castingDeviceName: moduleModel.castingDeviceName,
          asset: playerModel.asset,
        );
      case DisplayMode.localSmall:
        return new Stack(
          children: <Widget>[
            new Column(
              children: <Widget>[
                _deviceChooser,
                new Expanded(
                  child: new Stack(
                    fit: StackFit.passthrough,
                    children: <Widget>[
                      _screen,
                      playerModel.showControlOverlay
                          ? _playControls
                          : new Container(),
                    ],
                  ),
                ),
                new Scrubber(),
              ],
            ),
            // TODO(maryxia) SO-609: transparency with PhysicalModel
            new Positioned(
              bottom: 40.0,
              right: 48.0,
              child: new PhysicalModel(
                elevation: 2.0,
                color: Colors.black,
                child: new Offstage(
                  offstage: !playerModel.failedCast,
                  child: _buildRetry(moduleModel, playerModel),
                ),
              ),
            ),
          ],
        );
      case DisplayMode.localLarge:
      default:
        // This is in a Stack to fake the appearance of the Slider directly
        // below the video, while still allowing the Slider to have ample space
        // above AND below, to be tapped on
        // TODO(maryxia) SO-608 remove padding added due to no transparency
        return new Stack(
          children: <Widget>[
            new Column(
              children: <Widget>[
                _deviceChooser,
                new Expanded(
                  child: _screen,
                ),
                new AnimatedCrossFade(
                    duration: kPlayControlsAnimationTime,
                    firstChild: new Padding(
                      // height of play controls + Slider._kReactionRadius
                      padding: new EdgeInsets.only(bottom: 86.0),
                    ),
                    secondChild: new Container(),
                    crossFadeState: playerModel.showControlOverlay
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
            // TODO(maryxia) SO-609: transparency with PhysicalModel
            new Positioned(
              bottom: 100.0,
              right: 48.0,
              child: new PhysicalModel(
                elevation: 2.0,
                color: Colors.black,
                child: new Offstage(
                  offstage: !playerModel.failedCast,
                  child: _buildRetry(moduleModel, playerModel),
                ),
              ),
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
      VideoModuleModel moduleModel,
    ) {
      Size size = MediaQuery.of(context).size;
      bool smallScreen = false;
      if (size.width + size.height <= 912.0) {
        smallScreen = true;
      }
      if (moduleModel.getDisplayMode() != DisplayMode.remoteControl &&
          moduleModel.getDisplayMode() != DisplayMode.immersive &&
          moduleModel.getDisplayMode() != DisplayMode.standby) {
        if (smallScreen) {
          moduleModel.setDisplayMode(DisplayMode.localSmall);
        } else {
          moduleModel.setDisplayMode(DisplayMode.localLarge);
        }
      }
      return new ScopedModelDescendant<PlayerModel>(builder: (
        BuildContext context,
        Widget child,
        PlayerModel playerModel,
      ) {
        return new Container(
          color: Colors.black,
          child: _buildPlayerMode(moduleModel, playerModel, smallScreen),
        );
      });
    });
  }
}
