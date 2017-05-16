// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'album.dart';
import 'artist.dart';

/// Model representing a Spotify track
///
/// https://developer.spotify.com/web-api/object-model/#track-object-full
class Track {
  /// Name of track
  final String name;

  /// Artists who performed in track
  final List<Artist> artists;

  /// Album that the track appears in
  final Album album;

  /// Duration of track
  final Duration duration;

  /// The track number of this track in the album
  final int trackNumber;

  /// ID of track
  final String id;

  /// URL for media playback
  final String playbackUrl;

  /// Constructor
  Track({
    this.name,
    this.artists,
    this.album,
    this.duration,
    this.trackNumber,
    this.id,
    this.playbackUrl,
  });

  /// Create a new track from JSON data
  factory Track.fromJson(dynamic json) {
    return new Track(
      name: json['name'],
      artists: json['artists'] is List<dynamic>
          ? json['artists']
              .map((dynamic artistJson) => new Artist.fromJson(artistJson))
              .toList()
          : <Artist>[],
      // Tracks accessed within an album will have this as null
      album: json['album'] != null ? new Album.fromJson(json['album']) : null,
      duration: new Duration(milliseconds: json['duration_ms']),
      trackNumber: json['track_number'],
      id: json['id'],
      playbackUrl: json['preview_url'],
    );
  }

  /// Gets the default artwork for this track.
  /// Spotify uses the first image as the largest image.
  /// Returns NULL is there is no image in this track.
  String get defaultArtworkUrl {
    if (album != null && album.images != null && album.images.isNotEmpty) {
      return album.images.first.url;
    } else {
      return null;
    }
  }
}
