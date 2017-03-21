// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';

import 'playlist.dart';
import 'track.dart';
import 'user.dart';

/// Fixtures for Music
class MusicModelFixtures extends Fixtures {
  /// Generate a user
  User user() {
    return new User(
      id: 1,
      username: 'Nonch Harpin\'',
      avatarUrl:
          'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacf959cadb6c10d1c8c32/1454293330651/?format=600w',
      city: 'SF Bay',
      country: 'United States',
      trackCount: 12,
      playlistCount: 1,
      followersCount: 12,
      websiteUrl: 'http://www.nonch-harpin.com/',
    );
  }

  /// Generate a track
  Track track() {
    return new Track(
      title: 'Lil\' Antonin Scalia',
      duration: new Duration(seconds: 328),
      id: 1,
      user: user(),
      favoriteCount: 2,
      playbackCount: 110,
      artworkUrl:
          'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacd8289a60a49487afd52/1454034307698/NaSons.png',
    );
  }

  /// Generate a playlist
  Playlist playlist() {
    return new Playlist(
      title: 'Native Sons',
      description: '',
      duration: new Duration(seconds: 1640),
      id: 2,
      playlistType: 'album',
      trackCount: 5,
      artworkUrl:
          'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacd8289a60a49487afd52/1454034307698/NaSons.png',
      user: user(),
      tracks: <Track>[
        track(),
        track(),
        track(),
        track(),
        track(),
      ],
    );
  }
}
