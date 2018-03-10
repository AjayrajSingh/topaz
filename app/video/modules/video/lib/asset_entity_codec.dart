// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.logging/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

import 'asset.dart';

const String _kAssetEntityUri = 'com.fucshia.media.asset';
const String _kAssetTypeKey = 'asset_type';
const String _kAssetUriKey = 'asset_uri';
const String _kMovieType = 'movie';
const String _kSongType = 'song';
const String _kPlaylistType = 'playlist';
const String _kRemoteType = 'remote';

/// Convert an Asset to a form passable over a Link between processes.
/// For now, Asset is only used in video player and is therefore always
/// of type movie. This class repeats that behavior and only outputs the
/// Uri of the movie. When reading an Asset as an Entity, this class hard
/// codes the same values that were in the original code from which it
/// was ported.
// TODO(MS-1319): move to //topaz/public/lib/schemas
class AssetEntityCodec extends EntityCodec<Asset> {
  /// Constuctor assigns the proper values to en/decode VideoProgress objects.
  AssetEntityCodec()
      : super(
          type: _kAssetEntityUri,
          encode: _toJson,
          decode: _fromJson,
        );

  static String _toJson(Asset asset) {
    log.fine('Convert Asset to JSON: $asset');
    if (asset == null || asset.uri == null) {
      return 'null';
    }
    String assetType;
    switch (asset.type) {
      case AssetType.movie:
        assetType = _kMovieType;
        break;
      case AssetType.song:
        assetType = _kSongType;
        break;
      case AssetType.playlist:
        assetType = _kPlaylistType;
        break;
      case AssetType.remote:
        assetType = _kRemoteType;
        break;
    }
    return json.encode(<String, dynamic>{
      _kAssetTypeKey: assetType,
      _kAssetUriKey: asset.uri.toString()
    });
  }

  static Asset _fromJson(Object data) {
    log.fine('Convert to Asset from JSON: $data');
    if (data == null || !(data is String)) {
      return null;
    }
    String encoded = data;
    if (encoded.isEmpty || encoded == 'null') {
      return null;
    }
    Object decode = json.decode(encoded);
    if (decode == null || !(decode is Map)) {
      return null;
    }
    Map<String, dynamic> map = decode;
    switch (map[_kAssetTypeKey]) {
      case _kMovieType:
        return _movieFromMap(map);
      default:
        return null;
    }
  }

  static Asset _movieFromMap(Map<String, dynamic> map) {
    Uri uri;
    try {
      uri = Uri.parse(map[_kAssetUriKey]);
    } on Exception catch (error, trace) {
      log.warning(
          'Error parsing movie Uri: ${map[_kAssetUriKey]}', error, trace);
      return null;
    }
    if (uri == null) {
      return null;
    }
    String title = 'Discover Tahiti';
    String description = 'Take a trip and experience the ultimate island '
        'fantasy, Vahine Island in Tahiti.';
    String thumbnail = 'assets/video-thumbnail.png';
    String background = 'assets/video-background.png';

    return new Asset.movie(
      uri: uri,
      title: title,
      description: description,
      thumbnail: thumbnail,
      background: background,
    );
  }
}
