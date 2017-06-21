// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';
import '../widgets.dart';

final double _kZoomTimeInMicroseconds = 3000000.0;

/// The time slider/scrubber for the video player
class Scrubber extends StatelessWidget {
  /// Height of scrubber
  final double height;

  /// Constructor for the time slider/scrubber for the video player
  Scrubber({
    Key key,
    // TODO(maryxia) SO-543 re-add height
    this.height,
  })
      : super(key: key);

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

  Widget _buildProgressBar(VideoModuleModel model) {
    return new Slider(
      min: 0.0,
      max: 1.0,
      activeColor: Colors.grey[50],
      value: _getUnitProgress(model),
      onChanged: (double value) => _unitSeek(value, model),
    );
  }

  Widget _buildTimestamp(Duration timestamp, DisplayMode displayMode) {
    return new Center(
      child: new Container(
        padding: new EdgeInsets.symmetric(
            horizontal:
                (displayMode == DisplayMode.remoteControl ? 3.0 : 24.0)),
        child: new Text(
          _convertDurationToString(timestamp),
          style: new TextStyle(
            color: displayMode == DisplayMode.remoteControl
                ? Colors.grey[50]
                : Colors.grey[500],
            fontSize: displayMode == DisplayMode.localSmall ? 14.0 : 20.0,
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(VideoModuleModel model) {
    return new Positioned(
      height: 80.0,
      left: 0.0,
      top: 0.0,
      bottom: 0.0,
      child: _buildTimestamp(model.progress, DisplayMode.localLarge),
    );
  }

  Widget _buildDuration(VideoModuleModel model) {
    return new Positioned(
      height: 80.0,
      right: 0.0,
      top: 0.0,
      bottom: 0.0,
      child: _buildTimestamp(model.duration, DisplayMode.localLarge),
    );
  }

  Widget _buildScrubberMode(VideoModuleModel model) {
    switch (model.displayMode) {
      case DisplayMode.remoteControl:
        return new Column(
          children: <Widget>[
            new Center(
              child: new Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildTimestamp(model.progress, DisplayMode.remoteControl),
                  new Text(
                    '/',
                    style: new TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14.0,
                    ),
                  ),
                  _buildTimestamp(model.duration, DisplayMode.remoteControl),
                ],
              ),
            ),
            new Padding(
              padding: new EdgeInsets.only(top: 40.0),
              child: _buildProgressBar(model),
            ),
          ],
        );
      case DisplayMode.immersive:
        return new Row(
          children: <Widget>[
            new Expanded(
              child: _buildProgressBar(model),
            ),
          ],
        );
      case DisplayMode.localSmall:
        return new Row(
          children: <Widget>[
            _buildTimestamp(model.progress, DisplayMode.localSmall),
            new Expanded(
              child: _buildProgressBar(model),
            ),
            _buildTimestamp(model.duration, DisplayMode.localSmall),
          ],
        );
      case DisplayMode.localLarge:
      default:
        return new Container(
          color: Colors.black,
          child: new Stack(
            children: <Widget>[
              _buildProgress(model),
              _buildDuration(model),
              new PlayControls(
                primaryIconSize: 36.0,
                secondaryIconSize: 36.0,
                padding: 20.0,
              ),
              _buildProgressBar(model),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        // TODO(maryxia) SO-481 add offstage to hide scrubber after
        // user stops interacting with screen for x seconds
        return new Container(child: _buildScrubberMode(model));
      },
    );
  }
}
