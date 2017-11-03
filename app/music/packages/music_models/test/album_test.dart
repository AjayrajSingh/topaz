// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:music_models/music_models.dart';
import 'package:test/test.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson = await new File('mock_json/album.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Album album = new Album.fromJson(json);
    expect(album.name, json['name']);
    expect(album.artists[0].name, json['artists'][0]['name']);
    expect(album.images[0].url, json['images'][0]['url']);
    expect(album.tracks[0].name, json['tracks']['items'][0]['name']);
    expect(album.releaseDate.year, 2015);
    expect(album.genres.contains(json['genres'][0]), true);
    expect(album.id, json['id']);
  });

  test('getter: defaultArtworkUrl', () async {
    String imageUrl = 'imageUrl';
    Album album = new Album(
      images: <MusicImage>[
        new MusicImage(url: 'imageUrl'),
      ],
    );
    expect(album.defaultArtworkUrl, imageUrl);
  });

  test('getter: defaultArtworkUrl with no images', () async {
    Album album = new Album();
    expect(album.defaultArtworkUrl, null);
  });
}
