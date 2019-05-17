// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';

/// Tracks progress of Media playback
class MediaProgress extends Model {
  /// Constructor
  MediaProgress(this._durationMsec, this._normalizedProgress);

  /// Progress through media in the range [0..1]
  double _normalizedProgress;

  /// Full length of the media
  int _durationMsec;

  /// Progress through media as an absolute Duration.
  Duration get position => Duration(milliseconds: positionMsec);

  /// Progress through media as absolute milliseconds.
  int get positionMsec => (_durationMsec * _normalizedProgress).floor();

  /// Progress of media playback normalized in the range [0.0 .. 1.0];
  double get normalizedProgress => _normalizedProgress;

  /// Duration fo the vide in milliseconds
  int get durationMsec => _durationMsec;

  /// Update the duration of the media.
  set durationMsec(int durationMsec) {
    _durationMsec = durationMsec;
    notifyListeners();
  }

  /// Update the normalized progress of the media. This should be called
  /// with the value from the media player and is clamped to the range
  /// [0.0 .. 1.0].
  set normalizedProgress(double normalizedProgress) {
    _normalizedProgress = normalizedProgress;
    notifyListeners();
  }
}
