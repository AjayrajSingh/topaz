// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/com/fuchsia/media/media.dart';
import 'package:meta/meta.dart';

/// Describes an asset.
class Asset {
  /// Uri of the asset. Must be null for playlists and remotes, required for
  /// all other asset types.
  final Uri uri;

  /// Type of the asset.
  final AssetType type;

  /// Title of the asset. May be null.
  final String title;

  /// Description of asset. May be null.
  final String description;

  /// Thumbnail image file path for asset. May be null.
  final String thumbnail;

  /// Background image file path for asset. May be null.
  final String background;

  /// Artist to which the asset is attributed. May be null.
  final String artist;

  /// Album name for the asset. May be null.
  final String album;

  /// Children of the playlist asset. Must be null for other asset types.
  final List<Asset> children;

  /// Device on which remote player is running. Required for remotes, must be
  /// null for other asset types.
  final String device;

  /// Service number under which remote player is published. Required for
  /// remotes, must be null for other asset types.
  final String service;

  /// Position at which to start playing asset
  final Duration position;

  /// Construct an Asset from an AssetEntityData object
  Asset.fromEntity(AssetSpecifierEntityData data)
      : type = data.type,
        uri = Uri.parse(data.uri),
        title = null,
        description = null,
        thumbnail = null,
        background = null,
        artist = null,
        album = null,
        children = null,
        device = null,
        service = null,
        position = null;

  /// Constructs an asset describing a movie.
  Asset.movie({
    @required this.uri,
    @required this.title,
    @required this.description,
    @required this.thumbnail,
    @required this.background,
  })  : assert(uri != null),
        assert(title != null),
        assert(description != null),
        assert(thumbnail != null),
        assert(background != null),
        type = AssetType.movie,
        artist = null,
        album = null,
        children = null,
        device = null,
        service = null,
        position = null;

  /// Constructs an asset describing a song.
  Asset.song({
    @required this.uri,
    this.title,
    this.artist,
    this.album,
  })  : type = AssetType.song,
        children = null,
        description = null,
        thumbnail = null,
        background = null,
        device = null,
        service = null,
        position = null;

  /// Constructs an asset describing a playlist.
  Asset.playlist({
    @required this.children,
    this.title,
  })  : assert(children.isNotEmpty),
        assert(children.every((Asset c) =>
            c.type == AssetType.movie || c.type == AssetType.song)),
        type = AssetType.playlist,
        uri = null,
        description = null,
        thumbnail = null,
        background = null,
        artist = null,
        album = null,
        device = null,
        service = null,
        position = null;

  /// Constructs an asset describing a remote player.
  Asset.remote({
    @required this.device,
    @required this.service,
    @required this.position,
    @required this.title,
    @required this.description,
    @required this.thumbnail,
    @required this.background,
    @required this.uri,
  })  : assert(device != null),
        assert(service != null),
        assert(position != null),
        assert(title != null),
        assert(description != null),
        assert(thumbnail != null),
        assert(background != null),
        assert(uri != null),
        type = AssetType.remote,
        artist = null,
        album = null,
        children = null;
}
