// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/models/playlist.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson =
        await new File('models/mock_json/playlist.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Playlist playlist = new Playlist.fromJson(json);
    expect(playlist.title, json['title']);
    expect(playlist.description, json['description']);
    expect(playlist.duration.inMilliseconds, json['duration']);
    expect(playlist.id, json['id']);
    expect(playlist.trackCount, json['track_count']);
    expect(playlist.artworkUrl, json['artwork_url']);
    expect(playlist.playlistType, json['playlist_type']);
    expect(playlist.user.id, json['user']['id']);
    expect(playlist.user.username, json['user']['username']);
    expect(playlist.user.avatarUrl, json['user']['avatar_url']);
    expect(playlist.tracks.length, json['tracks'].length);
    expect(playlist.tracks[0].title, json['tracks'][0]['title']);
    expect(playlist.createdAt.year, 2010);
  });
}
