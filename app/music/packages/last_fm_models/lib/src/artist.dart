// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Model representing a Last FM artist
///
/// https://www.last.fm/api/show/artist.getInfo
class Artist {
  /// The name of the artist
  final String name;

  /// MusicBrainz ID of the artist
  ///
  /// https://musicbrainz.org/
  final String mbid;

  /// Biography of the artist
  final String bio;

  /// Profile image of artist
  final String imageUrl;

  /// Constructor
  Artist({
    this.name,
    this.mbid,
    this.bio,
    this.imageUrl,
  });

  /// Create an artist object from json data
  factory Artist.fromJson(dynamic json) {
    return new Artist(
      name: json['name'],
      mbid: json['mbid'],
      bio: json['bio'] is Map<String, dynamic> ? json['bio']['content'] : null,
      imageUrl: json['image'] is List<dynamic> &&
              json['image'].isNotEmpty &&
              json['image'].last is Map<String, String>
          ? json['image'].last['#text']
          : null,
    );
  }
}
