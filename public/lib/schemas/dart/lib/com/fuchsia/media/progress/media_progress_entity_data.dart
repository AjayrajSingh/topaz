// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Entity for communicating progress of media playback
class MediaProgressEntityData {
  /// Constructor
  const MediaProgressEntityData(this.durationMsec, this.normalizedProgress);

  /// Progress through media in the range [0..1]
  final double normalizedProgress;

  /// Full length of the media
  final int durationMsec;
}
