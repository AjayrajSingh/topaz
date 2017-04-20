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
    Artist artistFixture = fixtures.artist();

    String rawJson = await new File('mock_json/artist.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Artist artist = new Artist.fromJson(json);

    expect(artist.name, artistFixture.name);
    expect(artist.id, artistFixture.id);
  });
}
