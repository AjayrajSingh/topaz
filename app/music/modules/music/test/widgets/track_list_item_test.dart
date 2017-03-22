// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/src/models.dart';
import 'package:music/src/models/fixtures.dart';
import 'package:music/src/widgets.dart';

void main() {
  MusicModelFixtures fixtures = new MusicModelFixtures();
  testWidgets(
      'Test to see if tapping on the TrackListItem calls the appropriate '
      'callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    Key key = new UniqueKey();
    int taps = 0;

    await tester.pumpWidget(new Material(
      child: new TrackListItem(
        key: key,
        track: track,
        onTap: () {
          taps++;
        },
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byKey(key));
    expect(taps, 1);
  });
}
