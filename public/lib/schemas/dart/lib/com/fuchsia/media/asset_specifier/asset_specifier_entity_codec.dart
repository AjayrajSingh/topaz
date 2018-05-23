// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

import 'asset_specifier_entity_data.dart';

const String _kAssetSpecifierEntityUri = 'com.fucshia.media.asset_specifier';
const String _kAssetTypeKey = 'asset_type';
const String _kAssetUriKey = 'asset_uri';

const String _kMovieType = 'movie';
const String _kSongType = 'song';
const String _kPlaylistType = 'playlist';

/// Convert an AssetSpecifierEntityData to a form passable over a Link between
/// processes. For now, Asset is only used in video player and is therefore
/// always of type movie.
class AssetSpecifierEntityCodec extends EntityCodec<AssetSpecifierEntityData> {
  /// Constuctor assigns the proper values to en/decode VideoProgress objects.
  AssetSpecifierEntityCodec()
      : super(
          type: _kAssetSpecifierEntityUri,
          encode: _encode,
          decode: _decode,
        );

  static String _encode(AssetSpecifierEntityData asset) {
    log.finer('Convert Asset to JSON: $asset');
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
      default:
        throw const FormatException(
            'Converting AssetSpecifierEntityData with unsupported type');
    }
    return json.encode(
        <String, dynamic>{_kAssetTypeKey: assetType, _kAssetUriKey: asset.uri});
  }

  static AssetSpecifierEntityData _decode(Object data) {
    log.finer('Convert to Asset from JSON: $data');
    if (data == null) {
      return null;
    }
    if (data is! String) {
      throw const FormatException('Decoding Entity with unsupported type');
    }
    String encoded = data;
    if (encoded.isEmpty) {
      throw const FormatException('Decoding Entity with empty string');
    }
    if (encoded == 'null') {
      return null;
    }
    dynamic decode = json.decode(encoded);
    if (decode == null || decode is! Map) {
      throw const FormatException('Decoding Entity with invalid data');
    }
    Map<String, dynamic> map = decode.cast<String, dynamic>();
    if (map[_kAssetTypeKey] is! String) {
      throw const FormatException('Converting Entity with invalid values');
    }
    switch (map[_kAssetTypeKey]) {
      case _kMovieType:
        return _movieFromMap(map);
      default:
        throw new FormatException(
            'Converting AssetSpecifierEntityData with unsupported type: ${map[_kAssetTypeKey]}');
    }
  }

  static AssetSpecifierEntityData _movieFromMap(Map<String, dynamic> map) {
    if (map[_kAssetUriKey] == null || map[_kAssetUriKey] is! String) {
      throw new FormatException(
          'Converting AssetSpecifierEntityData with invalid Uri: ${map[_kAssetUriKey]}');
    }
    String uri = map[_kAssetUriKey];
    if (uri == 'null') {
      throw const FormatException(
          'Converting AssetSpecifierEntityData with null Uri');
    }
    return new AssetSpecifierEntityData.movie(uri: uri);
  }
}
