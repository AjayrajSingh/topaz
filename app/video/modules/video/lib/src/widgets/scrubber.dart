// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';

final double _kZoomTimeInMicroseconds = 3000000.0;

/// The time slider/scrubber for the video player
class Scrubber extends StatelessWidget {
  /// Constructor for the time slider/scrubber for the video player
  Scrubber({
    Key key,
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

  Widget _buildTimestamp(Duration timestamp) {
    return new Container(
      padding: new EdgeInsets.symmetric(horizontal: 24.0),
      child: new Text(
        _convertDurationToString(timestamp),
        style: new TextStyle(
          color: Colors.grey[50],
          fontSize: 14.0,
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
          height: 30.0,
          color: Colors.black,
          child: new Row(
            children: <Widget>[
              _buildTimestamp(model.progress),
              new Expanded(
                child: _buildProgressBar(model),
              ),
              _buildTimestamp(model.duration),
            ],
          ),
        );
      },
    );
  }
}
