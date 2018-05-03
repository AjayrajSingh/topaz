// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

const String _kYoutubeVideoIdEntityUri = 'com.fuchsia.youtube.videoid';

// All YouTube video IDs are 11 characters in length.
// This is also enforced in the YouTube code.
const int _kYoutubeVideoIdLength = 11;

/// Convert a request to set the videoID to a form passable over a Link between
/// modules.
class VideoIdEntityCodec extends EntityCodec<String> {
  /// Constuctor assigns the proper values to en/decode a the request.
  VideoIdEntityCodec()
      : super(
          type: _kYoutubeVideoIdEntityUri,
          encode: _toJson,
          decode: _fromJson,
        );

  static String _toJson(String videoId) {
    log.fine('Encode set video Id request to json: $videoId');
    if (videoId == null || videoId.length != _kYoutubeVideoIdLength) {
      log.warning('Invalid videoId encoding; returning null.');
      return 'null';
    }
    return json.encode(videoId);
  }

  static String _fromJson(String encoded) {
    log.fine('Decode request to set video ID: $encoded');
    if (encoded == null || encoded.isEmpty || encoded == 'null') {
      return null;
    }
    Object decoded = json.decode(encoded);
    if (decoded == null || decoded is! String) {
      return null;
    }
    String videoId = decoded;
    if (videoId.length != _kYoutubeVideoIdLength) {
      return null;
    }
    return videoId;
  }
}
