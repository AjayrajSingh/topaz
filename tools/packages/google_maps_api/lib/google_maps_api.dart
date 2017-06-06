// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/map.dart';

const String _kApiBaseUrl = 'maps.googleapis.com';

/// Units to use for showing distance
enum DistanceUnits {
  /// Imperial
  imperial,

  /// Metric
  metric,
}

/// API client for Google Maps
class GoogleMapsApi {
  /// API key used for Goggle Maps
  final String apiKey;

  /// Constructor
  GoogleMapsApi({@required this.apiKey}) {
    assert(apiKey != null);
  }

  String _getTravelModeParam(TravelMode mode) {
    String output;
    switch (mode) {
      case TravelMode.driving:
        output = 'driving';
        break;
      case TravelMode.walking:
        output = 'walking';
        break;
      case TravelMode.bicycling:
        output = 'bicycling';
        break;
      case TravelMode.transit:
        output = 'transit';
        break;
    }
    return output;
  }

  /// Retrieves the travel info (time & duration) from a startLocation to an
  /// end location.
  ///
  /// see:
  /// https://developers.google.com/maps/documentation/distance-matrix/start
  Future<TravelInfo> getTravelInfo({
    @required String startLocation,
    @required String endLocation,
    @required TravelMode travelMode,
    DistanceUnits units: DistanceUnits.imperial,
  }) async {
    assert(startLocation != null);
    assert(endLocation != null);
    assert(travelMode != null);
    Map<String, String> query = <String, String>{
      'origins': startLocation,
      'destinations': endLocation,
      'key': apiKey,
      'mode': _getTravelModeParam(travelMode),
      'units': units == DistanceUnits.imperial ? 'imperial' : 'metric',
    };
    Uri uri = new Uri.https(
      _kApiBaseUrl,
      '/maps/api/distancematrix/json',
      query,
    );
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    if (jsonData['status'] == 'OK' &&
        jsonData['rows'] is List<dynamic> &&
        jsonData['rows'][0]['elements'] is List<dynamic>) {
      return new TravelInfo.fromJson(jsonData['rows'][0]['elements'][0]);
    } else {
      return null;
    }
  }
}
