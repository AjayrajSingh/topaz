// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Holds strucutred data decoded from the Entity's data.
class GeolocationEntityData {
  /// value for the lattitude coordinate.
  final double lat;

  /// value for the longitude coordinate.
  final double long;

  /// Optional accuaracy value.
  final double accuracy;

  /// Create a new instance of [GeolocationEntityData].
  const GeolocationEntityData({
    @required this.lat,
    @required this.long,
    this.accuracy,
  })  : assert(lat != null),
        assert(long != null);

  @override
  String toString() {
    return 'GeolocationEntityData('
        'lat: $lat'
        'long: $long'
        'accuracy: $accuracy'
        ')';
  }
}
