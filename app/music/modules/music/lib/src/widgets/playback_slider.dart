// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../utils.dart';

const double _kSliderHeight = 4.0;
final Color _kBackgroundColor = Colors.grey[300];
final Color _kBarColor = Colors.grey[600];
final TextStyle _kTimeTextStyle = new TextStyle(
  fontSize: 12.0,
  color: Colors.grey[500],
);
const double _kTimeTextHeight = 24.0;

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

  /// Constructor
  PlaybackSlider({
    Key key,
    @required this.duration,
    @required this.playbackPosition,
    this.showTimeText: true,
  })
      : super(key: key) {
    assert(this.duration != null);
    assert(this.playbackPosition != null);
    assert(duration.compareTo(this.playbackPosition) >= 0);
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final Widget progressBar = new CustomPaint(
        size: new Size(constraints.maxWidth, _kSliderHeight),
        painter: new _PlaybackBarPainter(
          playbackRatio:
              playbackPosition.inMilliseconds / duration.inMilliseconds,
        ),
      );
      if (showTimeText) {
        return new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // This empty container is used to offset the time text to make
            // sure that the playback bar is visually centered.
            new Container(
              height: _kTimeTextHeight,
            ),
            progressBar,
            new Container(
              height: _kTimeTextHeight,
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new Text(
                    new DurationFormat(playbackPosition).playbackText,
                    style: _kTimeTextStyle,
                  ),
                  new Text(
                    new DurationFormat(duration).playbackText,
                    style: _kTimeTextStyle,
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
  }) {
    assert(playbackRatio != null);
    assert(playbackRatio >= 0.0 && playbackRatio <= 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = new Paint()
      ..color = _kBackgroundColor
      ..style = PaintingStyle.fill;
    final Paint foregroundPaint = new Paint()
      ..color = _kBarColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      new Rect.fromLTWH(0.0, 0.0, size.width, size.height),
      backgroundPaint,
    );
    canvas.drawRect(
      new Rect.fromLTWH(0.0, 0.0, size.width * playbackRatio, size.height),
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(_PlaybackBarPainter old) =>
      playbackRatio != old.playbackRatio;
}
