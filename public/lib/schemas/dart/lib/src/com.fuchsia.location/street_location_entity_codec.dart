// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';

import '../entity_codec.dart';
import 'street_location_entity_data.dart';

export 'street_location_entity_data.dart';

/// Translates Entity source data to and from the structured
/// [StreetLocationEntityData].
class StreetLocationEntityCodec extends EntityCodec<StreetLocationEntityData> {
  /// Create an instance of [StreetLocationEntityCodec].
  StreetLocationEntityCodec()
      : super(
          type: 'com.fuchsia.location.streetLocation',
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [StreetLocationEntityData] into a [String].
String _encode(StreetLocationEntityData data) {
  assert(data != null);

  Map<String, Object> map = <String, Object>{
    'location': <String, String>{
      'streetAddress': data.streetAddress,
      'locality': data.locality,
    },
  };

  return json.encode(map);
}

/// Decodes [String] into a structured [StreetLocationEntityCodec].
StreetLocationEntityData _decode(String data) {
  if (data == null || data.isEmpty || data == 'null') {
    throw new FormatException('Entity data is null: "$data"');
  }

  // TODO(MS-1428): use a schema to validate decoded value.
  Map<String, Object> map = json.decode(data);

  String streetAddress;
  String locality;

  try {
    Map<String, double> location = map['location'];
    streetAddress = location['streetAddress'];
    locality = location['locality'];
    // ignore: avoid_catches_without_on_clauses
  } catch (err, stackTrace) {
    log.warning(
        'Exception occured during JSON destructuring: \n$err\n$stackTrace');
    throw new FormatException('Invalid JSON data: "$map"');
  }

  return new StreetLocationEntityData(
    streetAddress: streetAddress,
    locality: locality,
  );
}
