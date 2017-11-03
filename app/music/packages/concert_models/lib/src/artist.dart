// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Model representing a Songkick aritist
///
/// See: http://www.songkick.com/developer/similar-artists
class Artist {
  /// Name of artist
  final String name;

  /// ID (Songkick) of artist
  final int id;

  /// Constructor
  Artist({
    this.name,
    this.id,
  });

  /// Creates an Artist from JSON data
  factory Artist.fromJson(Map<String, dynamic> json) {
    return new Artist(
      name: json['displayName'],
      id: json['id'],
    );
  }

  /// Profile image url for this artist
  String get imageUrl =>
      'http://images.sk-static.com/images/media/profile_images/artists/$id/huge_avatar';
}
