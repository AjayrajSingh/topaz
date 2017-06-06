// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/weather.dart';

const String _kApiBaseUrl = 'api.openweathermap.org';

/// API client for openweathermap.org
class WeatherApi {
  /// API key used for openweathermap.org
  final String apiKey;

  /// Constructor
  WeatherApi({@required this.apiKey}) {
    assert(apiKey != null);
  }

  /// Gets the current weather forecast for the given location which is
  /// specified by longitude/latitude coordinates
  Future<Forecast> getForecastForLocation({
    @required double longitude,
    @required double latitude,
  }) async {
    assert(longitude != null);
    assert(latitude != null);
    Map<String, String> query = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'APPID': apiKey,
      'units': 'imperial',
    };
    Uri uri = new Uri.http(
      _kApiBaseUrl,
      '/data/2.5/weather',
      query,
    );
    http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    dynamic jsonData = JSON.decode(response.body);
    return new Forecast.fromJson(jsonData);
  }
}
