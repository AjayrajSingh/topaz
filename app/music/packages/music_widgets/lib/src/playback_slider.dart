// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'utils.dart';

final Color _kBackgroundColor = Colors.grey[300];
final Color _kBarColor = Colors.grey[600];
final Color _kTextColor = Colors.grey[500];

/// Track Playback Slider
///
/// Used primarily in the player.
class PlaybackSlider extends StatelessWidget {
  /// Total duration that this [PlaybackSlider] represents
  final Duration duration;

  /// Current playback position
  ///
  /// The playback position should not be greater than the duration.
  final Duration playbackPosition;

  /// If true, show the text representation of the current playback position
  /// and the total duration.
  ///
  /// Defaults to true.
  final bool showTimeText;

  /// Font size for playback time text
  final double fontSize;

  /// Height of playback slider
  final double sliderHeight;

  /// Constructor
  PlaybackSlider({
    Key key,
    @required this.duration,
    @required this.playbackPosition,
    this.showTimeText: true,
    this.fontSize: 12.0,
    this.sliderHeight: 4.0,
  })
      : assert(duration != null),
        assert(playbackPosition != null),
        assert(duration.compareTo(playbackPosition) >= 0),
        super(key: key);

  double get _playbackRatio {
    if (duration.inMilliseconds == 0) {
      // This handles the situation when there is no track and when the duration
      // will be set to 0
      return 0.0;
    } else {
      return playbackPosition.inMilliseconds / duration.inMilliseconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final Widget progressBar = new CustomPaint(
        size: new Size(constraints.maxWidth, sliderHeight),
        painter: new _PlaybackBarPainter(playbackRatio: _playbackRatio),
      );
      if (showTimeText) {
        return new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // This empty container is used to offset the time text to make
            // sure that the playback bar is visually centered.
            new Container(
              height: fontSize * 2.0,
            ),
            progressBar,
            new Container(
              height: fontSize * 2.0,
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new Text(
                    new DurationFormat(playbackPosition).playbackText,
                    style: new TextStyle(
                      color: _kTextColor,
                      fontSize: fontSize,
                    ),
                  ),
                  new Text(
                    new DurationFormat(duration).playbackText,
                    style: new TextStyle(
                      color: _kTextColor,
                      fontSize: fontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        return progressBar;
      }
    });
  }
}

/// Customer painter to draw the progress bar for playback
class _PlaybackBarPainter extends CustomPainter {
  /// The ratio (0-1.0) of the playback position
  final double playbackRatio;

  _PlaybackBarPainter({
    @required this.playbackRatio,
  })
      : assert(playbackRatio != null),
        assert(playbackRatio >= 0.0 && playbackRatio <= 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = new Paint()
      ..color = _kBackgroundColor
      ..style = PaintingStyle.fill;
    final Paint foregroundPaint = new Paint()
      ..color = _kBarColor
      ..style = PaintingStyle.fill;

    canvas
      ..drawRect(
        new Rect.fromLTWH(0.0, 0.0, size.width, size.height),
        backgroundPaint,
      )
      ..drawRect(
        new Rect.fromLTWH(0.0, 0.0, size.width * playbackRatio, size.height),
        foregroundPaint,
      );
  }

  @override
  bool shouldRepaint(_PlaybackBarPainter old) =>
      playbackRatio != old.playbackRatio;
}
