// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/models/user.dart';

void main() {
  test('fromJSON() constructor', () async {
    String rawJson =
        await new File('models/mock_json/user.json').readAsString();
    dynamic json = JSON.decode(rawJson);
    User user = new User.fromJson(json);
    expect(user.id, json['id']);
    expect(user.username, json['username']);
    expect(user.city, json['city']);
    expect(user.country, json['country']);
    expect(user.trackCount, json['track_count']);
    expect(user.playlistCount, json['playlist_count']);
    expect(user.followersCount, json['followers_count']);
    expect(user.websiteUrl, json['website']);
  });
}
