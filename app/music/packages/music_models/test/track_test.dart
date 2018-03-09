// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:io';

import 'package:music_models/music_models.dart';
import 'package:test/test.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson = await new File('mock_json/track.json').readAsString();
    dynamic decoded = json.decode(rawJson);
    Track track = new Track.fromJson(decoded);
    expect(track.name, decoded['name']);
    expect(track.artists[0].name, decoded['artists'][0]['name']);
    expect(track.album.name, decoded['album']['name']);
    expect(track.duration, new Duration(milliseconds: decoded['duration_ms']));
    expect(track.trackNumber, decoded['track_number']);
    expect(track.id, decoded['id']);
    expect(track.playbackUrl, decoded['preview_url']);
  });

  test('getter: defaultArtworkUrl', () async {
    String imageUrl = 'imageUrl';
    Track track = new Track(
      album: new Album(
        images: <MusicImage>[
          new MusicImage(url: 'imageUrl'),
        ],
      ),
    );
    expect(track.defaultArtworkUrl, imageUrl);
  });

  test('getter: defaultArtworkUrl with no images', () async {
    Track track = new Track();
    expect(track.defaultArtworkUrl, null);
  });
}
