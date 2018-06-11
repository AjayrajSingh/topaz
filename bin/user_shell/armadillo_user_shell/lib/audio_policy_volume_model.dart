// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/now.dart';
import 'package:lib.media.dart/audio.dart';

/// Uses an [Audio] object to set and get volume.
class AudioPolicyVolumeModel extends VolumeModel {
  /// Used to get and set the volume.
  final Audio audio;

  /// Ranges from 0.0 to 1.0.
  double _level = 0.0;

  /// Constructor.
  AudioPolicyVolumeModel({this.audio}) {
    _setLevelFromAudioPolicy();
    audio.updateCallback = _setLevelFromAudioPolicy;
  }

  @override
  double get level => _level;

  @override
  set level(double level) {
    if (level == _level) {
      return;
    }
    _level = level;
    audio.systemAudioPerceivedLevel = level;
    notifyListeners();
  }

  void _setLevelFromAudioPolicy() {
    level = audio.systemAudioMuted
        ? 0.0
        : audio.systemAudioPerceivedLevel;
  }
}
