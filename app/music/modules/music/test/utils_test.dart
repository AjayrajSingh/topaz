// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/utils.dart';

void main() {
  test('getDurationText()', () {
    // hours, minutes and seconds
    expect(
      getDurationText(new Duration(hours: 1, minutes: 23, seconds: 31)),
      '1:23:31',
    );

    // hours, minutes and seconds with minutes < 10
    expect(
      getDurationText(new Duration(hours: 1, minutes: 2, seconds: 31)),
      '1:02:31',
    );

    // minutes and seconds
    expect(
      getDurationText(new Duration(minutes: 1, seconds: 30)),
      '1:30',
    );

    // minutes and seconds with seconds < 10
    expect(
      getDurationText(new Duration(minutes: 1, seconds: 1)),
      '1:01',
    );

    // 0 minute and seconds > 10
    expect(
      getDurationText(new Duration(minutes: 0, seconds: 30)),
      '0:30',
    );

    // seconds only
    expect(
      getDurationText(new Duration(seconds: 6)),
      '0:06',
    );
  });
}
