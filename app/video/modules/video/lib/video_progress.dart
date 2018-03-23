// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/com/fuchsia/media/media.dart';
import 'package:lib.widgets/model.dart';

/// Tracks progress of Video playback
class VideoProgress extends Model {
  /// Constructor
  VideoProgress(this._durationMsec, this._normalizedProgress);

  /// Convert this object to an Entity suitable for sending over a Link
  MediaProgressEntityData toEntity() =>
      new MediaProgressEntityData(_durationMsec, _normalizedProgress);

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
