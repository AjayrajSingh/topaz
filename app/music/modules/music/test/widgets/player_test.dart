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
      'Test to see if tapping on the repeat button calls the appropriate '
      'callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    int taps = 0;

    await tester.pumpWidget(new SizedBox(
      // This ensures that the large version of the player will be used
      width: 800.0,
      child: new Material(
        child: new Player(
          currentTrack: track,
          playbackPosition: new Duration(seconds: 30),
          onToggleRepeat: () {
            taps++;
          },
        ),
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.repeat));
    expect(taps, 1);
  });

  testWidgets(
      'Test to see if tapping on the shuffle button calls the appropriate '
      'callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    int taps = 0;

    await tester.pumpWidget(new SizedBox(
      // This ensures that the large version of the player will be used
      width: 800.0,
      child: new Material(
        child: new Player(
          currentTrack: track,
          playbackPosition: new Duration(seconds: 30),
          onToggleShuffle: () {
            taps++;
          },
        ),
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.shuffle));
    expect(taps, 1);
  });

  testWidgets(
      'Test to see if tapping on the "skip previous" button calls the '
      'appropriate callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    int taps = 0;

    await tester.pumpWidget(new Material(
      child: new Player(
        currentTrack: track,
        playbackPosition: new Duration(seconds: 30),
        onSkipPrevious: () {
          taps++;
        },
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byWidgetPredicate((Widget widget) =>
        widget is Icon && widget.icon == Icons.skip_previous));
    expect(taps, 1);
  });

  testWidgets(
      'Test to see if tapping on the "skip next" button calls the '
      'appropriate callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    int taps = 0;

    await tester.pumpWidget(new Material(
      child: new Player(
        currentTrack: track,
        playbackPosition: new Duration(seconds: 30),
        onSkipNext: () {
          taps++;
        },
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.skip_next));
    expect(taps, 1);
  });

  testWidgets(
      'Test to see if tapping on the play/pause button calls the appropriate '
      'callback', (WidgetTester tester) async {
    Track track = fixtures.track();
    int taps = 0;

    await tester.pumpWidget(new Material(
      child: new Player(
        currentTrack: track,
        playbackPosition: new Duration(seconds: 30),
        onTogglePlay: () {
          taps++;
        },
      ),
    ));

    expect(taps, 0);
    await tester.tap(find.byWidgetPredicate((Widget widget) =>
        widget is Icon && widget.icon == Icons.play_circle_outline));
    expect(taps, 1);
  });

  testWidgets(
      'Play/Pause button should be set to Pause if isPlaying is set to true',
      (WidgetTester tester) async {
    Track track = fixtures.track();

    await tester.pumpWidget(new Material(
      child: new Player(
        currentTrack: track,
        playbackPosition: new Duration(seconds: 30),
        isPlaying: false,
      ),
    ));

    expect(
      find.byWidgetPredicate((Widget widget) =>
          widget is Icon && widget.icon == Icons.play_circle_outline),
      findsOneWidget,
    );

    await tester.pumpWidget(new Material(
      child: new Player(
        currentTrack: track,
        playbackPosition: new Duration(seconds: 30),
        isPlaying: true,
      ),
    ));

    expect(
      find.byWidgetPredicate((Widget widget) =>
          widget is Icon && widget.icon == Icons.pause_circle_outline),
      findsOneWidget,
    );
  });

  testWidgets(
      'Shuffle icon should be the theme primaryColor when isShuffled is true',
      (WidgetTester tester) async {
    Track track = fixtures.track();
    Color primaryColor = Colors.blue[500];

    await tester.pumpWidget(new SizedBox(
      // This ensures that the large version of the player will be used
      width: 800.0,
      child: new Material(
        child: new Theme(
          data: new ThemeData(primaryColor: primaryColor),
          child: new Player(
            currentTrack: track,
            playbackPosition: new Duration(seconds: 30),
            isShuffled: true,
          ),
        ),
      ),
    ));

    Icon icon = tester.widget(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.shuffle));
    expect(icon.color, primaryColor);
  });

  testWidgets(
      'Repeat icon should be the theme primaryColor when isRepeated is true',
      (WidgetTester tester) async {
    Track track = fixtures.track();
    Color primaryColor = Colors.blue[500];

    await tester.pumpWidget(new SizedBox(
      // This ensures that the large version of the player will be used
      width: 800.0,
      child: new Material(
        child: new Theme(
          data: new ThemeData(primaryColor: primaryColor),
          child: new Player(
            currentTrack: track,
            playbackPosition: new Duration(seconds: 30),
            isRepeated: true,
          ),
        ),
      ),
    ));

    Icon icon = tester.widget(find.byWidgetPredicate(
        (Widget widget) => widget is Icon && widget.icon == Icons.repeat));
    expect(icon.color, primaryColor);
  });
}
