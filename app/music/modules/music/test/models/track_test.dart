// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/models/track.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson =
        await new File('models/mock_json/track.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    Track track = new Track.fromJson(json);
    expect(track.title, json['title']);
    expect(track.description, json['description']);
    expect(track.duration.inMilliseconds, json['duration']);
    expect(track.id, json['id']);
    expect(track.user.id, json['user']['id']);
    expect(track.user.username, json['user']['username']);
    expect(track.user.avatarUrl, json['user']['avatar_url']);
    expect(track.favoriteCount, json['favoritings_count']);
    expect(track.playbackCount, json['playback_count']);
    expect(track.artworkUrl, json['artwork_url']);
    expect(track.streamUrl, json['stream_url']);
    expect(track.videoUrl, json['video_url']);
  });
}
