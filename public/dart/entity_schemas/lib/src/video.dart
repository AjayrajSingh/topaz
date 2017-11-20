// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

const String _kType = 'Video';

/// The Entity schema for a video
class Video {
  /// Video location: URL or file path if local
  final String location;

  /// Video mimeType
  final String mimeType;

  /// Constructor
  Video({
    @required this.location,
    @required this.mimeType,
  })
      : assert(location != null),
        assert(mimeType != null);

  /// Instantiate a Video from a JSON string
  factory Video.fromJson(String json) {
    try {
      Map<String, String> decodedJson = JSON.decode(json);
      return new Video(
        location: decodedJson['location'],
        mimeType: decodedJson['mimeType'] ?? '',
      );
    } on Exception catch (e) {
      // TODO errors
      log.warning('$_kType entity error when decoding from json string: $json'
          '\nerror: $e');
      rethrow;
    }
  }

  /// Gets entity type
  static String getType() => _kType;

  @override
  String toString() => toJson();

  /// Encodes a Video entity into a JSON string
  String toJson() {
    return JSON.encode(<String, String>{
      'location': location,
      'mimeType': mimeType,
    });
  }
}
