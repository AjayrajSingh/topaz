// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import './user.dart';

/// Model representing a SoundCloud track
///
/// https://developers.soundcloud.com/docs/api/reference#tracks
class Track {
  /// Title of the track
  final String title;

  /// Description for the track
  final String description;

  /// Duration of the track
  final Duration duration;

  /// ID for the track
  final int id;

  /// User who is the owner of this track
  final User user;

  /// Number of times this track has been favorited
  final int favoriteCount;

  /// Number of times this track has been played
  final int playbackCount;

  /// URL for artwork image of track
  final String artworkUrl;

  /// URL to stream this track
  final String streamUrl;

  /// URL of external video for this track
  final String videoUrl;

  /// Constructor
  Track({
    this.title,
    this.description,
    this.duration,
    this.id,
    this.user,
    this.favoriteCount,
    this.playbackCount,
    this.artworkUrl,
    this.streamUrl,
    this.videoUrl,
  });

  /// Create a new track from JSON data
  factory Track.fromJson(dynamic json) {
    return new Track(
      title: json['title'],
      description: json['description'],
      duration: new Duration(milliseconds: json['duration']),
      id: json['id'],
      user: new User.fromJson(json['user']),
      favoriteCount: json['favoritings_count'],
      playbackCount: json['playback_count'],
      artworkUrl: json['artwork_url'],
      streamUrl: json['stream_url'],
      videoUrl: json['video_url'],
    );
  }
}
