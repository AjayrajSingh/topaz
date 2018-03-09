// Copyright 2017 Th%e Fuchsia Authors. All rights reserved.
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

  /// Video name (i.e. Document name)
  final String name;

  /// Video description
  final String description;

  /// Video thumbnail image's location
  final String thumbnailLocation;

  /// Constructor
  Video({
    @required this.location,
    @required this.name,
    @required this.description,
    @required this.thumbnailLocation,
  })
      : assert(location != null),
        assert(name != null),
        assert(description != null),
        assert(thumbnailLocation != null);

  /// Instantiate a Video from a JSON string
  factory Video.fromJson(String encodedJson) {
    try {
      Map<String, String> decodedJson = json.decode(encodedJson);
      return new Video(
        location: decodedJson['location'],
        name: decodedJson['name'] ?? '',
        description: decodedJson['description'] ?? '',
        thumbnailLocation: decodedJson['thumbnailLocation'] ?? '',
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
    return json.encode(<String, String>{
      'location': location,
      'name': name,
      'description': description,
      'thumbnailLocation': thumbnailLocation,
    });
  }
}
