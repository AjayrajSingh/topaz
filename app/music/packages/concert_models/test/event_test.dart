// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:concert_models/concert_models.dart';
import 'package:test/test.dart';

void main() {
  test('fromJSON() constructor', () async {
    MusicModelFixtures fixtures = new MusicModelFixtures();
    Event eventFixture = fixtures.event();

    String rawJson = await new File('mock_json/event.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Event event = new Event.fromJson(json);
    expect(event.name, eventFixture.name);
    expect(event.type, eventFixture.type);
    expect(event.startTime, eventFixture.startTime);
    expect(event.date, eventFixture.date);
    expect(event.venue.id, eventFixture.venue.id);
    expect(event.performances[0].id, eventFixture.performances[0].id);
    expect(event.performances[0].name, eventFixture.performances[0].name);
    expect(event.performances[0].billingIndex,
        eventFixture.performances[0].billingIndex);
    expect(
      event.performances[0].billing,
      eventFixture.performances[0].billing,
    );
    expect(event.id, eventFixture.id);
    expect(event.url, eventFixture.url);
  });
}
