// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/now.dart';
import 'package:lib.media.dart/audio.dart';

/// Uses an [Audio] object to set and get volume.
class AudioPolicyVolumeModel extends VolumeModel {
  /// Used to get and set the volume.
  final Audio audio;

  /// Constructor.
  AudioPolicyVolumeModel({this.audio}) {
    audio.updateCallback = notifyListeners;
  }

  @override
  double get level => audio.systemAudioMuted
                          ? 0.0
                          : audio.systemAudioPerceivedLevel;


  @override
  set level(double level) {
    if (level == this.level) {
      return;
    }

    audio.systemAudioPerceivedLevel = level;
    if (level > 0.0) {
      audio.systemAudioMuted = false;
    }

    notifyListeners();
  }
}
