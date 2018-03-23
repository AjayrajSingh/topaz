// Copyright 2018 The Fuchsia Authors. All rights reserved.
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

  /// Remote player
  remote,
}

/// Describes the location of an Asset. The Asset could be a movie, song or a
/// playlist, which is actually the collection of AssetSpecifiers.
class AssetSpecifierEntityData {
  /// String conversion of the Uri of the asset. Must be null for playlists,
  /// required for all other asset types.
  final String uri;

  /// Type of the asset.
  final AssetType type;

  /// Children of the playlist asset. Must be null for other asset types.
  final List<AssetSpecifierEntityData> children;

  /// Constructs an asset describing a movie.
  AssetSpecifierEntityData.movie({@required this.uri})
      : assert(uri != null),
        type = AssetType.movie,
        children = null;

  /// Constructs an asset describing a song.
  AssetSpecifierEntityData.song({@required this.uri})
      : type = AssetType.song,
        children = null;

  /// Constructs an asset describing a playlist.
  AssetSpecifierEntityData.playlist({
    @required this.children,
  })  : assert(children.isNotEmpty),
        assert(children.every((AssetSpecifierEntityData c) =>
            c.type == AssetType.movie || c.type == AssetType.song)),
        type = AssetType.playlist;
}
