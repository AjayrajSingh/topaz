// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import './track.dart';
import './user.dart';

/// Model representing a SoundCloud playlist
///
/// https://developers.soundcloud.com/docs/api/reference#playlists
class Playlist {
  /// Title of the playlist
  final String title;

  /// Description of the playlist
  final String description;

  /// Duration of the entire playlist
  final Duration duration;

  /// ID of the playlist
  final int id;

  /// Type of the playlist
  final String playlistType;

  /// Number of tracks in this playlist
  final int trackCount;

  /// URL for artwork image of playlist
  final String artworkUrl;

  /// User who is the owner of this playlist
  final User user;

  /// Tracks of this playlist
  final List<Track> tracks;

  /// Constructor
  Playlist({
    this.title,
    this.description,
    this.duration,
    this.id,
    this.playlistType,
    this.trackCount,
    this.artworkUrl,
    this.user,
    this.tracks,
  });

  /// Create a new playlist from JSON data
  factory Playlist.fromJson(dynamic json) {
    return new Playlist(
      title: json['title'],
      description: json['description'],
      duration: new Duration(milliseconds: json['duration']),
      id: json['id'],
      playlistType: json['playlist_type'],
      trackCount: json['track_count'],
      artworkUrl: json['artwork_url'],
      user: new User.fromJson(json['user']),
      tracks: json['tracks']
          ?.map((dynamic trackJson) => new Track.fromJson(trackJson))
          ?.toList(),
    );
  }
}
