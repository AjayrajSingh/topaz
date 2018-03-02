// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:lib.media.flutter/media_player_controller.dart';
import 'package:lib.widgets/model.dart';

const String _kDurationKey = 'duration_msec';
const String _kProgressKey = 'normalized_progress';

/// Tracks progress of Video playback
class VideoProgress extends Model {
  /// Constructor
  VideoProgress(this._durationMsec, this._normalizedProgress);

  //// Create a VideoProgress from a Map previously output by toMap()
  factory VideoProgress.fromMap(Map <String, dynamic> map) {
    int durationMsec = map[_kDurationKey];
    double normalizedProgress = map[_kProgressKey];
    if (durationMsec == null || normalizedProgress == null) {
      throw const FormatException('Missing required field for VideoProgress');
    }
    return new VideoProgress(durationMsec, normalizedProgress);
  }

  /// Convert to a Map suitable for sending via json, etc. over a Link
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      _kDurationKey: _durationMsec,
      _kProgressKey: _normalizedProgress,
    };
  }

  /// Progress through video in the range [0..1]
  double _normalizedProgress;

  /// Full length of the video
  int _durationMsec;

  /// Progress through video as an absolute Duration.
  Duration get position => new Duration(milliseconds: positionMsec);

  /// Progress through video as absolute milliseconds.
  int get positionMsec => (_durationMsec * _normalizedProgress).floor();

  /// Progress of video playback normalized in the range [0.0 .. 1.0];
  double get normalizedProgress => _normalizedProgress;

  /// Duration fo the vide in milliseconds
  int get durationMsec => _durationMsec;

  /// Update the duration of the video.
  set durationMsec(int durationMsec) {
    _durationMsec = durationMsec;
    notifyListeners();
  }

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

  final VideoProgress _progress = new VideoProgress(0, 0.0);

  /// Constructor
  VideoProgressMonitor(this._controller);

  /// Get last reported video progress
  VideoProgress get progress => _progress;

  /// Begin sending periodic progress events
  void start() {
    _started = true;
    _progress.durationMsec = _controller.duration.inMilliseconds;
    _timer =
        new Timer.periodic(const Duration(milliseconds: 250), _handleTimer);
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
