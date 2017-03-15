// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Model representing a SoundCloud user
///
/// Note: There is no different between a "artist" and "user" in SoundCloud
///
/// https://developers.soundcloud.com/docs/api/reference#users
class User {
  /// ID of user
  final int id;

  /// Username of user
  final String username;

  /// URL for user avatar
  final String avatarUrl;

  /// City that user lives in
  final String city;

  /// Country that user lives in
  final String country;

  /// Number of tracks that the user has created
  final int trackCount;

  /// Number of playlist that the user has created
  final int playlistCount;

  /// Number of other users who follow this user
  final int followersCount;

  /// URL for the user's external website
  final String websiteUrl;

  /// Constructor
  User({
    this.id,
    this.username,
    this.avatarUrl,
    this.city,
    this.country,
    this.trackCount,
    this.playlistCount,
    this.followersCount,
    this.websiteUrl,
  });

  /// Create a new user from JSON data
  factory User.fromJson(dynamic json) {
    return new User(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      city: json['city'],
      country: json['country'],
      trackCount: json['track_count'],
      playlistCount: json['playlist_count'],
      followersCount: json['followers_count'],
      websiteUrl: json['website'],
    );
  }
}
