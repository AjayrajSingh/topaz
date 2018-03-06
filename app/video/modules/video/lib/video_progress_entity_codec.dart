// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';

import 'video_progress.dart';

const String _kDurationKey = 'duration_msec';
const String _kProgressKey = 'normalized_progress';

/// Codec for reading/writing VideoProgress Entities to a Link.
class VideoProgressEntityCodec extends EntityCodec<VideoProgress> {
  /// Constuctor assigns the proper values to en/decode VideoProgress objects.
  VideoProgressEntityCodec() :
    super(
      type: 'com.fucshia.video.progress',
      encode: _toJson,
      decode: _fromJson,
    );

  // Create a VideoProgress from a Map previously output by toMap()
  static VideoProgress _fromJson(Object data) {
    log.finer('Convert to VideoProgress from JSON: $data');
    if (data == null || !(data is String)) {
      return null;
    }
    String json = data;
    if (json.isEmpty || json == 'null') {
      return null;
    }
    Object decode = JSON.decode(json);
    if (decode == null || !(decode is Map)) {
      return null;
    }
    Map<String, dynamic> map = decode;
    if (map[_kDurationKey] == null || !(map[_kDurationKey] is int) ||
        map[_kProgressKey] == null || !(map[_kProgressKey] is double)) {
      return null;
    }
    return new VideoProgress(map[_kDurationKey], map[_kProgressKey]);
  }

  // Convert to a Map suitable for sending via json, etc. over a Link
  static String _toJson(VideoProgress progress) {
    log.finer('Convert VideoProgress to JSON: $progress');
    if (progress == null) {
      return 'null';
    }
    return JSON.encode(<String, dynamic>{
      _kDurationKey: progress.durationMsec,
      _kProgressKey: progress.normalizedProgress,
    });
  }
}
