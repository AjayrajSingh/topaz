// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../modular/player_model.dart';

/// The play controls in the video player
class PlayControls extends StatelessWidget {
  /// Size of the play/pause icons
  final double primaryIconSize;

  /// Size of the fast forward and rewind icons
  final double secondaryIconSize;

  /// Padding around play control icons
  final double padding;

  /// Constructor for the play controls in the video player
  const PlayControls({
    Key key,
    @required this.primaryIconSize,
    @required this.secondaryIconSize,
    @required this.padding,
  }) : super(key: key);

  double get _kZoomTimeInMicroseconds => 3000000.0;

  Widget _createIconButton(
      {Icon icon, double iconSize, VoidCallback callback}) {
    return new Container(
      padding: new EdgeInsets.all(padding),
      child: new IconButton(
        icon: icon,
        iconSize: iconSize,
        color: Colors.grey[50],
        disabledColor: Colors.grey[500],
        onPressed: callback,
      ),
    );
  }

  double _getZoomTime(PlayerModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return 0.0;
    }
    return _kZoomTimeInMicroseconds / durationInMicroseconds;
  }

  void _forward(PlayerModel model) {
    model
      ..pause()
      ..normalizedSeek(min(model.normalizedProgress + _getZoomTime(model), 1.0))
      ..play();
  }

  void _rewind(PlayerModel model) {
    model
      ..pause()
      ..normalizedSeek(max(model.normalizedProgress - _getZoomTime(model), 0.0))
      ..play();
  }

  void _togglePlayPause(PlayerModel model) {
    if (model.playing) {
      model.pause();
    } else {
      model.play();
    }
  }

  Widget _buildPlayControls(PlayerModel model) {
    return new Center(
      child: new Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _createIconButton(
              icon: new Icon(Icons.fast_rewind),
              iconSize: secondaryIconSize,
              callback: model.progress.inMicroseconds == 0
                  ? null
                  : () => _rewind(model)),
          _createIconButton(
              icon: new Icon(model.playing ? Icons.pause : Icons.play_arrow),
              iconSize: primaryIconSize,
              callback: () => _togglePlayPause(model)),
          _createIconButton(
              icon: new Icon(Icons.fast_forward),
              iconSize: secondaryIconSize,
              callback:
                  model.progress.inMicroseconds == model.duration.inMicroseconds
                      ? null
                      : () => _forward(model)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<PlayerModel>(
      builder: (
        BuildContext context,
        Widget child,
        PlayerModel model,
      ) {
        return _buildPlayControls(model);
      },
    );
  }
}
