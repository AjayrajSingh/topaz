// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// The asset types.
enum AssetType {
  /// Individual assets containing both audio and video.
  movie,

  /// Individual assets containing only audio.
  song,

  /// Composite assets that consist of a list of other assets.
  playlist,
}

/// Describes an asset.
class Asset {
  /// Uri of the asset. Must be null for playlists, required for
  /// all other asset types.
  final Uri uri;

  /// Type of the asset.
  final AssetType type;

  /// Title of the asset. May be null.
  final String title;

  /// Artist to which the asset is attributed. May be null.
  final String artist;

  /// Album name for the asset. May be null.
  final String album;

  /// Children of the playlist asset. Must be null for other asset types.
  final List<Asset> children;

  /// Whether the asset should loop back to the beginning when it ends.
  final bool loop;

  /// Constructs an asset describing a movie.
  Asset.movie({
    @required this.uri,
    this.title,
    this.artist,
    this.album,
    this.loop,
  })
      : type = AssetType.movie,
        children = null;

  /// Constructs an asset describing a song.
  Asset.song({
    @required this.uri,
    this.title,
    this.artist,
    this.album,
    this.loop,
  })
      : type = AssetType.song,
        children = null;

  /// Constructs an asset describing a playlist.
  Asset.playlist({
    @required this.children,
    this.title,
    this.loop,
  })
      : assert(children.isNotEmpty),
        type = AssetType.playlist,
        uri = null,
        artist = null,
        album = null {
    assert(children.every(
        (Asset c) => c.type == AssetType.movie || c.type == AssetType.song));
  }
}
