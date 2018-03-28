// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';

import '../entity_codec.dart';
import 'geolocation_entity_data.dart';

export 'geolocation_entity_data.dart';

/// Translates Entity source data to and from the structured
/// [GeolocationEntityData].
class GeolocationEntityCodec extends EntityCodec<GeolocationEntityData> {
  /// Create an instance of [GeolocationEntityCodec].
  GeolocationEntityCodec()
      : super(
          type: 'com.fuchsia.location.geolocation',
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [GeolocationEntityData] into a [String].
String _encode(GeolocationEntityData data) {
  assert(data != null);

  Map<String, Object> map = <String, Object>{
    'location': <String, double>{
      'lat': data.lat,
      'long': data.long,
    },
    'accuracy': data.accuracy,
  };

  return json.encode(map);
}

/// Decodes [String] into a structured [GeolocationEntityCodec].
GeolocationEntityData _decode(String data) {
  if (data == null || data.isEmpty || data == 'null') {
    throw new FormatException('Entity data is null: "$data"');
  }

  // TODO(MS-1428): use a schema to validate decoded value.
  Map<String, Object> map = json.decode(data);

  double lat;
  double long;
  double accuracy;

  try {
    Map<String, double> location = map['location'];
    lat = location['lat'];
    long = location['long'];
    accuracy = map['accuracy'];
    // ignore: avoid_catches_without_on_clauses
  } catch (err, stackTrace) {
    log.warning(
        'Exception occured during JSON destructuring: \n$err\n$stackTrace');
    throw new FormatException('Invalid JSON data: "$map"');
  }

  return new GeolocationEntityData(
    lat: lat,
    long: long,
    accuracy: accuracy,
  );
}
