// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:music_models/music_models.dart';
import 'package:test/test.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson = await new File('mock_json/track.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Track track = new Track.fromJson(json);
    expect(track.name, json['name']);
    expect(track.artists[0].name, json['artists'][0]['name']);
    expect(track.album.name, json['album']['name']);
    expect(track.duration, new Duration(milliseconds: json['duration_ms']));
    expect(track.trackNumber, json['track_number']);
    expect(track.id, json['id']);
    expect(track.playbackUrl, json['preview_url']);
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
