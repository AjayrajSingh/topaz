// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/player_model.dart';
import '../widgets.dart';

/// Video player layout
class Player extends StatelessWidget {
  /// Constructor for the video player layout
  const Player({
    Key key,
  })
      : super(key: key);

  final Widget _screen = const Screen();

  final Widget _playControls = const PlayControls(
    primaryIconSize: 80.0,
    secondaryIconSize: 64.0,
    padding: 0.0,
  );

  Widget _buildPlayerMode(PlayerModel playerModel, bool smallScreen) {
    switch (playerModel.displayMode) {
      case DisplayMode.localSmall:
        return new Stack(
          children: <Widget>[
            new Column(
              children: <Widget>[
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
                const Scrubber(),
              ],
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
                new Expanded(
                  child: _screen,
                ),
                new AnimatedCrossFade(
                    duration: kPlayControlsAnimationTime,
                    firstChild: const Padding(
                      // height of play controls + Slider._kReactionRadius
                      padding: const EdgeInsets.only(bottom: 86.0),
                    ),
                    secondChild: new Container(),
                    crossFadeState: playerModel.showControlOverlay
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond)
              ],
            ),
            // Scrubber for this Mode includes PlayControls
            const Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: const Scrubber(),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<PlayerModel>(builder: (
      BuildContext context,
      Widget child,
      PlayerModel playerModel,
    ) {
      Size size = MediaQuery.of(context).size;
      bool smallScreen = false;
      if (size.width + size.height <= 912.0) {
        smallScreen = true;
      }
      if (smallScreen) {
        playerModel.displayMode = DisplayMode.localSmall;
      } else {
        playerModel.displayMode = DisplayMode.localLarge;
      }
      return new ScopedModelDescendant<PlayerModel>(builder: (
        BuildContext context,
        Widget child,
        PlayerModel playerModel,
      ) {
        return new Container(
          color: Colors.black,
          child: _buildPlayerMode(playerModel, smallScreen),
        );
      });
    });
  }
}
