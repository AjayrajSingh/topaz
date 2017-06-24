// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:models/weather.dart';
import 'package:weather_api/weather_api.dart';
import 'package:widgets/common.dart';

/// [ModuleModel] that manages the state of the Forecast Module
class ForecastModuleModel extends ModuleModel {
  /// Constructor
  ForecastModuleModel({@required String apiKey})
      : _api = new WeatherApi(apiKey: apiKey),
        super();

  /// Weather Forecast
  Forecast get forecast => _forecast;
  Forecast _forecast;

  /// The loading status of the request
  LoadingStatus get loadingStatus => _loadingStatus;
  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  final WeatherApi _api;

  /// Retrieves the full event based on the given ID
  Future<Null> _fetchWeather({
    @required double latitude,
    @required double longitude,
  }) async {
    assert(latitude != null);
    assert(longitude != null);
    try {
      _forecast = await _api.getForecastForLocation(
        latitude: latitude,
        longitude: longitude,
      );
      if (_forecast != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Update the event ID
  @override
  void onNotify(String json) {
    log.fine('onNotify call');
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['longitude'] is double && doc['latitude'] is double) {
      _fetchWeather(
        latitude: doc['latitude'],
        longitude: doc['longitude'],
      );
    }
  }
}
