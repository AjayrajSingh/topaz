// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

// This module expects to obtain the location string through the link
// provided from the parent, in the following document id / property key.
const String _kMapDocRoot = 'map-doc';
const String _kMapLocationKey = 'map-location-key';
const String _kMapHeightKey = 'map-height-key';
const String _kMapWidthKey = 'map-width-key';
const String _kMapZoomkey = 'map-zoom-key';

/// The model class for the map module.
class MapModuleModel extends ModuleModel {
  /// Gets the location string.
  String get mapLocation => _mapLocation;
  String _mapLocation;

  /// Gets the desired height of the map.
  /// This value should match the height of the child view of the map module.
  double get mapHeight => _mapHeight;
  double _mapHeight;

  /// Gets the desired width of the map.
  double get mapWidth => _mapWidth;
  double _mapWidth;

  /// Gets the zoom level for map.
  int get mapZoom => _mapZoom;
  int _mapZoom;

  @override
  void onNotify(String json) {
    log.fine('onNotify call $json');

    final dynamic doc = JSON.decode(json);
    if (doc is! Map || doc[_kMapDocRoot] is! Map) {
      log.fine('No map root found in json.');
      return;
    }
    final Map<String, dynamic> mapDoc = doc[_kMapDocRoot];

    if (mapDoc[_kMapLocationKey] is! String ||
        mapDoc[_kMapHeightKey] is! double ||
        mapDoc[_kMapWidthKey] is! double ||
        mapDoc[_kMapZoomkey] is! int) {
      log.severe('Bad json values in LinkWatcherImpl.notify');
      return;
    }

    _mapLocation = mapDoc[_kMapLocationKey];
    _mapHeight = mapDoc[_kMapHeightKey];
    _mapWidth = mapDoc[_kMapWidthKey];
    _mapZoom = mapDoc[_kMapZoomkey];

    log.fine('_location: $_mapLocation');
    log.fine('_mapHeight: $_mapHeight');
    log.fine('_mapWidth: $_mapWidth');
    log.fine('_mapZoom: $_mapZoom');

    notifyListeners();
  }
}
