// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:lib.media.flutter/media_player_controller.dart';
import 'package:lib.widgets/model.dart';

/// Tracks progress of Video playback
class VideoProgress extends Model {
  /// Constructor
  VideoProgress() {
    _normalizedProgress = 0.0;
    duration = const Duration(seconds: 0);
  }

  /// Progress through video in the range [0..1]
  double _normalizedProgress;

  /// Full length of the video
  Duration duration;

  /// Progress through video as an absolute Duration.
  Duration get position => new Duration(
      milliseconds: (duration.inMilliseconds * _normalizedProgress).floor());

  /// Progress of video playback normalized in the range [0.0 .. 1.0];
  double get normalizedProgress => _normalizedProgress;

  /// Update the normalized progress of the video. This should be called
  /// with the value from the video player and is clamped to the range
  /// [0.0 .. 1.0].
  set normalizedProgress(double normalizedProgress) {
    _normalizedProgress = normalizedProgress;
    notifyListeners();
  }
}

/// Listener class to publish video progress events
class VideoProgressMonitor {
  Timer _timer;
  bool _started = false;
  MediaPlayerController _controller;

  final VideoProgress _progress = new VideoProgress();

  /// Constructor
  VideoProgressMonitor(this._controller);

  /// Get last reported video progress
  VideoProgress get progress => _progress;

  /// Begin sending periodic progress events
  void start() {
    _started = true;
    _progress.duration = _controller.duration;
    _timer =
        new Timer.periodic(const Duration(milliseconds: 500), _handleTimer);
  }

  /// Stop sending periodic progress events
  void stop() {
    _started = false;
    _timer.cancel();
    _timer = null;
  }

  void _handleTimer(Timer timer) {
    if (!_started) {
      return;
    }
    _updateProgress();
  }

  /// This public version can be invoked by caller in special instances to
  /// force immediate notification. (e.g. seek within video)
  void updateProgress() {
    _updateProgress();
  }

  void _updateProgress() {
    // We may not know the duration of the video initially
    _progress.duration = _controller.duration;

    double normalizedProgress = _controller.normalizedProgress;
    if (normalizedProgress != _progress.normalizedProgress) {
      _progress.normalizedProgress = normalizedProgress;
      if (normalizedProgress == 1.0) {
        _timer.cancel();
      }
    }
  }
}
