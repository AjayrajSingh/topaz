// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';

import 'album.dart';
import 'artist.dart';
import 'music_image.dart';
import 'track.dart';

/// Fixtures for Music
class MusicModelFixtures extends Fixtures {
  /// Generate an artist
  Artist artist() {
    return new Artist(
      name: 'Nonch Harpin\'',
      images: <MusicImage>[
        new MusicImage(
          height: 600.0,
          width: 600.0,
          url:
              'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacf959cadb6c10d1c8c32/1454293330651/?format=600w',
        ),
      ],
      genres: <String>['Post Modern Jazz', 'Rap'],
      id: 'artist_1',
      followersCount: 6,
    );
  }

  /// Generate a track
  Track track() {
    return new Track(
        name: 'Lil\' Antonin Scalia',
        duration: new Duration(seconds: 328),
        id: 'track_1',
        trackNumber: 1,
        artists: <Artist>[artist()],
        album: new Album(
          name: 'Native Sons',
          artists: <Artist>[artist()],
          images: <MusicImage>[
            new MusicImage(
              height: 100.0,
              width: 100.0,
              url:
                  'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacd8289a60a49487afd52/1454034307698/NaSons.png',
            ),
          ],
          id: 'album_1',
        ));
  }

  /// Generate an album
  Album album() {
    return new Album(
      name: 'Native Sons',
      artists: <Artist>[artist()],
      images: <MusicImage>[
        new MusicImage(
          height: 100.0,
          width: 100.0,
          url:
              'https://static1.squarespace.com/static/54ce5022e4b047e0ce41d15f/t/56aacd8289a60a49487afd52/1454034307698/NaSons.png',
        ),
      ],
      tracks: <Track>[
        track(),
        track(),
        track(),
        track(),
        track(),
      ],
      releaseDate: DateTime.parse('2015-11-18'),
      albumType: 'album',
      genres: <String>['Post Modern Jazz', 'Rap'],
      id: 'album_1',
    );
  }
}
