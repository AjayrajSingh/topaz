// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/utils.dart';

void main() {
  test('DurationFormat.playbackText', () {
    // hours, minutes and seconds
    expect(
      new DurationFormat(new Duration(hours: 1, minutes: 23, seconds: 31)).playbackText,
      '1:23:31',
    );

    // hours, minutes and seconds with minutes < 10
    expect(
        new DurationFormat(new Duration(hours: 1, minutes: 2, seconds: 31)).playbackText,
      '1:02:31',
    );

    // minutes and seconds
    expect(
      new DurationFormat(new Duration(minutes: 1, seconds: 30)).playbackText,
      '1:30',
    );

    // minutes and seconds with seconds < 10
    expect(
      new DurationFormat(new Duration(minutes: 1, seconds: 1)).playbackText,
      '1:01',
    );

    // 0 minute and seconds > 10
    expect(
      new DurationFormat(new Duration(minutes: 0, seconds: 30)).playbackText,
      '0:30',
    );

    // seconds only
    expect(
      new DurationFormat(new Duration(seconds: 6)).playbackText,
      '0:06',
    );
  });

  test('getDurationTotalText()', () {
    // hours and minutes
    expect(
      new DurationFormat(new Duration(hours: 1, minutes: 23)).totalText,
      '1hr 23m',
    );

    // hours only
    expect(
      new DurationFormat(new Duration(hours: 4)).totalText,
      '4hr',
    );

    // minutes only
    expect(
      new DurationFormat(new Duration(minutes: 50, seconds: 3)).totalText,
      '50m',
    );

    // seconds only
    expect(
      new DurationFormat(new Duration(seconds: 12)).totalText,
      '12s',
    );

    // no duration
    expect(
      new DurationFormat(new Duration()).totalText,
      '0s',
    );
  });
}
