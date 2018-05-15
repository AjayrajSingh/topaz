// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';

import 'media_progress_entity_data.dart';

const String _kDurationKey = 'duration_msec';
const String _kProgressKey = 'normalized_progress';

/// Codec for reading/writing MediaProgress Entities to a Link.
// TODO(MS-1319): move to //topaz/public/lib/schemas
class MediaProgressEntityCodec extends EntityCodec<MediaProgressEntityData> {
  /// Constuctor assigns the proper values to en/decode MediaProgress objects.
  MediaProgressEntityCodec()
      : super(
          type: 'com.fuchsia.media.progress',
          encode: _encode,
          decode: _decode,
        );

  // Create a MediaProgress from a json string previously output by encode()
  static MediaProgressEntityData _decode(Object data) {
    log.finer('Convert to MediaProgressEntityData from JSON: $data');
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
    Object decode = json.decode(encoded);
    if (decode == null || decode is! Map) {
      throw const FormatException('Decoding Entity with invalid data');
    }
    Map<String, dynamic> map = decode;
    if (map[_kDurationKey] == null ||
        map[_kDurationKey] is! int ||
        map[_kProgressKey] == null ||
        map[_kProgressKey] is! double) {
      throw const FormatException('Converting Entity with invalid values');
    }
    return new MediaProgressEntityData(map[_kDurationKey], map[_kProgressKey]);
  }

  // Convert to a json string suitable for sending over a Link
  static String _encode(MediaProgressEntityData progress) {
    log.finer('Convert MediaProgressEntityData to JSON: $progress');
    if (progress == null) {
      return 'null';
    }
    return json.encode(<String, dynamic>{
      _kDurationKey: progress.durationMsec,
      _kProgressKey: progress.normalizedProgress,
    });
  }
}
