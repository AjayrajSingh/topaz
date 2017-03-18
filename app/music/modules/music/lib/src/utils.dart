// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Returns the human-readable form of a given duration of the the typical
/// format that is used for music tracks: h:mm:ss.
///
/// This only needs to be precise to the second
String getDurationText(Duration duration) {
  assert(duration != null);
  final int hours = (duration.inSeconds / Duration.SECONDS_PER_HOUR).floor();
  final int minutes =
      ((duration.inSeconds - (hours * Duration.SECONDS_PER_HOUR)) /
              Duration.SECONDS_PER_MINUTE)
          .floor();
  final int seconds = duration.inSeconds -
      (hours * Duration.SECONDS_PER_HOUR) -
      (minutes * Duration.SECONDS_PER_MINUTE);

  String output = '';

  if (hours > 0) {
    output += '$hours:';
  }

  if (minutes < 10 && hours > 0) {
    output += '0$minutes:';
  } else {
    output += '$minutes:';
  }

  if (seconds < 10) {
    output += '0$seconds';
  } else {
    output += '$seconds';
  }

  return output;
}
