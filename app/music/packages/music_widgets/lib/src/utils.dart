// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Formats a given [Duration] in various human-friendly formats
class DurationFormat {
  int _hours;
  int _minutes;
  int _seconds;

  /// Constructor
  DurationFormat(Duration duration) : assert(duration != null) {
    _hours = (duration.inSeconds / Duration.secondsPerHour).floor();
    _minutes = ((duration.inSeconds - (_hours * Duration.secondsPerHour)) /
            Duration.secondsPerMinute)
        .floor();
    _seconds = duration.inSeconds -
        (_hours * Duration.secondsPerHour) -
        (_minutes * Duration.secondsPerMinute);
  }

  /// Returns the human-readable form of a given duration of the the typical
  /// format that is used for music track playback: h:mm:ss.
  ///
  /// This only needs to be precise to the second
  String get playbackText {
    StringBuffer buffer = new StringBuffer();

    if (_hours > 0) {
      buffer.write('$_hours:');
    }

    if (_minutes < 10 && _hours > 0) {
      buffer.write('0$_minutes:');
    } else {
      buffer.write('$_minutes:');
    }

    if (_seconds < 10) {
      buffer.write('0$_seconds');
    } else {
      buffer.write('$_seconds');
    }

    return buffer.toString();
  }

  /// Returns the human-readable form of a given duration that is usually used for
  /// total duration of a playlist: 1hr 2m or 39s
  ///
  /// Only show seconds if the duration is below a minute
  String get totalText {
    StringBuffer buffer = new StringBuffer();

    if (_hours > 0) {
      buffer.write('${_hours}hr');
      if (_minutes > 0) {
        buffer.write(' ');
      }
    }

    if (_minutes > 0) {
      buffer.write('${_minutes}m');
    }

    if (_hours == 0 && _minutes == 0) {
      buffer.write('${_seconds}s');
    }

    return buffer.toString();
  }
}
