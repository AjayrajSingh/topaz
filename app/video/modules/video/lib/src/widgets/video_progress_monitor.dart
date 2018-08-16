// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// import 'dart:async';

import 'dart:async';

import 'package:lib.mediaplayer.flutter/media_player_controller.dart';
import 'package:lib.mediaplayer.flutter/media_progress.dart';

/// Listener class to publish video progress events
class VideoProgressMonitor {
  Timer _timer;
  bool _started = false;
  MediaPlayerController _controller;

  final MediaProgress _progress = new MediaProgress(0, 0.0);

  /// Constructor
  VideoProgressMonitor(this._controller);

  /// Get last reported video progress
  MediaProgress get progress => _progress;

  /// Begin sending periodic progress events
  void start() {
    _started = true;
    _progress.durationMsec = _controller.duration.inMilliseconds;
    _timer =
        new Timer.periodic(const Duration(milliseconds: 1000), _handleTimer);
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
    if (_progress.durationMsec == 0) {
      _progress.durationMsec = _controller.duration.inMilliseconds;
    }

    double normalizedProgress = _controller.normalizedProgress;
    if (normalizedProgress != _progress.normalizedProgress) {
      _progress.normalizedProgress = normalizedProgress;
      if (normalizedProgress == 1.0) {
        _timer.cancel();
      }
    }
  }
}
