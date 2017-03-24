// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'music_image.dart';

/// Model representing a Spotify artist
///
/// https://developer.spotify.com/web-api/get-artist/
class Artist {
  /// The name of the artist
  final String name;

  /// Images of the artist in various sizes
  final List<MusicImage> images;

  /// List of genres the artist is associated with
  final List<String> genres;

  /// ID of the artist
  final String id;

  /// The number of users that follow this artist
  final int followersCount;

  /// Constructor
  Artist({
    this.name,
    this.images,
    this.genres,
    this.id,
    this.followersCount,
  });

  /// Create a full artist object from json data
  factory Artist.fromJson(dynamic json) {
    return new Artist(
      name: json['name'],
      images: MusicImage.listFromJson(json['images']),
      genres: json['genres'] is List<String> ? json['genres'] : null,
      followersCount:
          json['followers'] != null && json['followers']['total'] is int
              ? json['followers']['total']
              : null,
      id: json['id'],
    );
  }
}
