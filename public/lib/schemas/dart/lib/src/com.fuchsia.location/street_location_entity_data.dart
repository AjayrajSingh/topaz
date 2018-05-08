// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

// TODO(maryxia) MS-1530 make this more granular, e.g. zip code
/// Holds strucutred data decoded from the Entity's data.
class StreetLocationEntityData {
  /// Street address, e.g. '123 A St'
  final String streetAddress;

  /// Locality, e.g. 'San Francisco'
  final String locality;

  /// Create a new instance of [StreetLocationEntityData].
  const StreetLocationEntityData({
    @required this.streetAddress,
    @required this.locality,
  })  : assert(streetAddress != null),
        assert(locality != null);

  @override
  String toString() {
    return 'StreetLocationEntityData('
        'streetAddress: $streetAddress'
        'locality: $locality'
        ')';
  }

  String toStreetAddress() {
    return '$streetAddress, $locality';
  }
}
