// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/modular.dart';

const String _kTravelInfoModuleUrl = 'file:///system/apps/travel_info';
const String _kForecastModuleUrl = 'file:///system/apps/weather_forecast';
const String _kMapModuleUrl = 'file:///system/apps/map';
const String _kMapDocRoot = 'map-doc';
const String _kMapLocationKey = 'map-location-key';
const String _kMapHeightKey = 'map-height-key';
const String _kMapWidthKey = 'map-width-key';
const String _kMapZoomkey = 'map-zoom-key';
const int _kMapZoomValue = 15;
const double _kMapSizeValue = 250.0;
const double _kMapWudValue = 250.0;
const String _kMapLinkName = 'map_link';

/// [ModuleModel] that manages the state of the Forecast Module
class LocationDetailsModuleModel extends ModuleModel {
  /// Child View Connection for the Map
  ChildViewConnection get mapViewConn => _mapViewConn;
  ChildViewConnection _mapViewConn;

  /// Child View Connection for Weather
  ChildViewConnection get forecastViewConn => _forecastViewConn;
  ChildViewConnection _forecastViewConn;

  /// Child View Connection for Travel Info
  ChildViewConnection get travelInfoViewConn => _travelInfoViewConn;
  ChildViewConnection _travelInfoViewConn;

  /// Link for Embedded Map Module
  final LinkProxy _mapLink = new LinkProxy();

  /// Update the event ID
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    if (doc is Map<String, dynamic> &&
        doc['longitude'] is double &&
        doc['latitude'] is double) {
      _updateTravelInfoModule();
      _updateForecastModule();
      _updateMapModule(
        latitude: doc['latitude'],
        longitude: doc['longitude'],
      );
    }
  }

  void _updateMapModule({double longitude, double latitude}) {
    assert(longitude != null);
    assert(latitude != null);

    String mapLinkData = JSON.encode(<String, dynamic>{
      _kMapZoomkey: _kMapZoomValue,
      _kMapHeightKey: _kMapSizeValue,
      _kMapWidthKey: _kMapSizeValue,
      _kMapLocationKey: '$latitude,$longitude',
    });

    if (_mapViewConn != null) {
      _mapLink.set(<String>[_kMapDocRoot], mapLinkData);
    } else {
      moduleContext.getLink(_kMapLinkName, _mapLink.ctrl.request());
      _mapLink.set(<String>[_kMapDocRoot], mapLinkData);
      InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
      InterfacePair<ModuleController> moduleController =
          new InterfacePair<ModuleController>();
      moduleContext.startModule(
        'map',
        _kMapModuleUrl,
        _kMapLinkName,
        null,
        null,
        moduleController.passRequest(),
        viewOwner.passRequest(),
      );
      _mapViewConn = new ChildViewConnection(viewOwner.passHandle());
    }
    notifyListeners();
  }

  void _updateForecastModule() {
    if (_forecastViewConn != null) {
      return;
    } else {
      InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
      InterfacePair<ModuleController> moduleController =
          new InterfacePair<ModuleController>();
      moduleContext.startModule(
        'Weather Forecast',
        _kForecastModuleUrl,
        null, // Uses the link of the parent module
        null,
        null,
        moduleController.passRequest(),
        viewOwner.passRequest(),
      );
      _forecastViewConn = new ChildViewConnection(viewOwner.passHandle());
    }
    notifyListeners();
  }

  void _updateTravelInfoModule() {
    if (_travelInfoViewConn != null) {
      return;
    } else {
      InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
      InterfacePair<ModuleController> moduleController =
          new InterfacePair<ModuleController>();
      moduleContext.startModule(
        'Travel Info',
        _kTravelInfoModuleUrl,
        null, // Uses the link of the parent module
        null,
        null,
        moduleController.passRequest(),
        viewOwner.passRequest(),
      );
      _travelInfoViewConn = new ChildViewConnection(viewOwner.passHandle());
    }
    notifyListeners();
  }
}
