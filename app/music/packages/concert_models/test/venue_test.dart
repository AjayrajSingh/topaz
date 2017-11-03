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
    Venue venueFixture = fixtures.venue();

    String rawJson = await new File('mock_json/venue.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Venue venue = new Venue.fromJson(json);
    expect(venue.name, venueFixture.name);
    expect(venue.description, venueFixture.description);
    expect(venue.website, venueFixture.website);
    expect(venue.metroArea.name, venueFixture.metroArea.name);
    expect(venue.metroArea.country, venueFixture.metroArea.country);
    expect(venue.metroArea.id, venueFixture.metroArea.id);
    expect(venue.city.name, venueFixture.city.name);
    expect(venue.city.country, venueFixture.city.country);
    expect(venue.city.id, venueFixture.city.id);
    expect(venue.street, venueFixture.street);
    expect(venue.zip, venueFixture.zip);
    expect(venue.phoneNumber, venueFixture.phoneNumber);
    expect(venue.latitude, venueFixture.latitude);
    expect(venue.longitude, venueFixture.longitude);
    expect(venue.id, venueFixture.id);
  });
}
