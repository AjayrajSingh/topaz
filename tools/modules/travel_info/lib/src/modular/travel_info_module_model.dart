// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:google_maps_api/google_maps_api.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:models/map.dart';
import 'package:widgets/common.dart';

const String _kDefaultStartLocation = '56 Henry San Francisco';

/// [ModuleModel] that manages the state of the Travel Info Module
class TravelInfoModuleModel extends ModuleModel {
  /// Constructor
  TravelInfoModuleModel({@required String apiKey})
      : api = new GoogleMapsApi(apiKey: apiKey),
        super();

  /// API key for google maps
  final GoogleMapsApi api;

  /// Travel info data
  Map<TravelMode, TravelInfo> get travelInfo => _travelInfo;
  Map<TravelMode, TravelInfo> _travelInfo;

  /// Loading status
  LoadingStatus get loadingStatus => _loadingStatus;
  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Retrieves the full event based on the given ID
  Future<Null> _fetchTravelInfo({
    @required String startLocation,
    @required String endLocation,
  }) async {
    try {
      List<dynamic> response = await Future
          .wait(TravelMode.values.map((TravelMode mode) => api.getTravelInfo(
                startLocation: startLocation,
                endLocation: endLocation,
                travelMode: mode,
              )));
      if (response.any((TravelInfo info) => info == null)) {
        _loadingStatus = LoadingStatus.failed;
      } else {
        _travelInfo = new Map<TravelMode, TravelInfo>();
        int index = 0;
        TravelMode.values.forEach((TravelMode mode) {
          _travelInfo[mode] = response[index];
          index++;
        });
        _loadingStatus = LoadingStatus.completed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Update the event ID
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['longitude'] is double && doc['latitude'] is double) {
      String location = '${doc['latitude']},${doc['longitude']}';
      _fetchTravelInfo(
        startLocation: _kDefaultStartLocation,
        endLocation: location,
      );
    }
  }
}
