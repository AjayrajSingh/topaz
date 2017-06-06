// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';

final double _kZoomTimeInMicroseconds = 3000000.0;

/// The play bar to video player.
class PlayBar extends StatelessWidget {
  /// The play bar for video player
  PlayBar({
    Key key,
  })
      : super(key: key);

  Widget _createIconButton(Icon icon, VoidCallback callback) {
    return new Container(
      child: new IconButton(
        icon: icon,
        iconSize: 28.0,
        color: Colors.grey[50],
        disabledColor: Colors.grey[800],
        onPressed: callback,
      ),
    );
  }

  /// Returns progress as a value from 0.0 to 1.0 inclusive.
  double _getUnitProgress(VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return 0.0;
    }
    return model.progress.inMicroseconds / durationInMicroseconds;
  }

  /// Seeks to a position given as a value from 0.0 to 1.0 inclusive.
  void _unitSeek(double unitPosition, VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return;
    }
    model.seek(new Duration(
        microseconds: (unitPosition * durationInMicroseconds).round()));
  }

  /// Converts a duration to a string indicating seconds, such as '1:15:00' or
  /// '2:40'
  static String _convertDurationToString(Duration duration) {
    int seconds = duration.inSeconds;
    int minutes = seconds ~/ 60;
    seconds %= 60;
    int hours = minutes ~/ 60;
    minutes %= 60;

    String hoursString = hours == 0 ? '' : '$hours:';
    String minutesString =
        (hours == 0 || minutes > 9) ? '$minutes:' : '0$minutes:';
    String secondsString = seconds > 9 ? '$seconds' : '0$seconds';

    return '$hoursString$minutesString$secondsString';
  }

  double _getZoomTime(VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return 0.0;
    }
    return _kZoomTimeInMicroseconds / durationInMicroseconds;
  }

  void _forward(VideoModuleModel model) {
    _unitSeek(min(_getUnitProgress(model) + _getZoomTime(model), 1.0), model);
  }

  void _rewind(VideoModuleModel model) {
    _unitSeek(max(_getUnitProgress(model) - _getZoomTime(model), 0.0), model);
  }

  void _togglePlayPause(VideoModuleModel model) {
    if (model.playing) {
      model.pause();
    } else {
      model.play();
    }
  }

  Widget _buildProgressBar(VideoModuleModel model) {
    return new Stack(
      children: <Widget>[
        new Container(height: 2.0, color: Colors.grey[800]),
        // TODO(maryxia) SO-476 extend slider edges
        // TODO(maryxia) SO-481 increase tappable area
        new Container(
          height: 2.0,
          child: new Slider(
            min: 0.0,
            max: 1.0,
            activeColor: Colors.grey[50],
            value: _getUnitProgress(model),
            onChanged: (double value) => _unitSeek(value, model),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayBarButtons(VideoModuleModel model) {
    return new Center(
      child: new Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _createIconButton(new Icon(Icons.fast_rewind),
              model.progress.inMicroseconds == 0 ? null : () => _rewind(model)),
          model.playing
              ? _createIconButton(
                  new Icon(Icons.pause), () => _togglePlayPause(model))
              : _createIconButton(
                  new Icon(Icons.play_arrow), () => _togglePlayPause(model)),
          _createIconButton(
              new Icon(Icons.fast_forward),
              model.progress.inMicroseconds == model.duration.inMicroseconds
                  ? null
                  : () => _forward(model)),
        ],
      ),
    );
  }

  Widget _buildProgress(VideoModuleModel model) {
    return new Positioned(
      left: 0.0,
      child: _buildTimestamp(model.progress),
    );
  }

  Widget _buildDuration(VideoModuleModel model) {
    return new Positioned(
      right: 0.0,
      child: _buildTimestamp(model.duration),
    );
  }

  Widget _buildTimestamp(Duration timestamp) {
    return new Center(
      child: new Container(
        height: 45.0,
        alignment: FractionalOffset.center,
        padding: new EdgeInsets.only(left: 24.0, right: 24.0),
        child: new Text(
          _convertDurationToString(timestamp),
          style: new TextStyle(
            color: Colors.grey[50],
            fontSize: 14.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        // TODO(maryxia) SO-481 add offstage
        return new Container(
          color: Colors.black,
          child: new Stack(
            children: <Widget>[
              _buildProgress(model),
              _buildDuration(model),
              _buildPlayBarButtons(model),
              _buildProgressBar(model),
            ],
          ),
        );
      },
    );
  }
}
