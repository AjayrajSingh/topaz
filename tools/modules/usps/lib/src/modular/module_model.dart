// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:widgets/common.dart';

// This module expects to obtain the USPS tracking code string through the link
// provided from the parent, in the following document id / property key.
const String _kMapDocRoot = 'map-doc';
const String _kMapLocationKey = 'map-location-key';
const String _kMapHeightKey = 'map-height-key';
const String _kMapWidthKey = 'map-width-key';
const String _kMapZoomkey = 'map-zoom-key';
const int _kMapZoomValue = 10;
const double _kMapHeightValue = 200.0;
const double _kMapWidthValue = 1200.0;

const String _kMapModuleUrl = 'file:///system/apps/map';

/// The model class for the usps module.
class UspsModuleModel extends ModuleModel {
  /// Gets the USPS tracking code for the package.
  String get trackingCode => _trackingCode;
  String _trackingCode;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServiceProvider,
  ) {
    super.onReady(moduleContext, link, incomingServiceProvider);

    _addEmbeddedChildBuilders();

    // Initially set the location to empty.
    // We won't know the location until the USPS logic runs and fetches the
    // locations.
    updateLocation('');
  }

  @override
  void onNotify(String json) {
    log.fine('onNotify call');

    final dynamic doc = JSON.decode(json);
    try {
      _trackingCode = doc['view']['query parameters']['qtc_tLabels1'];
    } catch (_) {
      _trackingCode = null;
    }

    if (_trackingCode == null) {
      log.severe('No usps tracking key found in json.');
    } else {
      log.fine('_trackingCode: $_trackingCode');
      notifyListeners();
    }
  }

  /// Adds all the [EmbeddedChildBuilder]s that this module supports.
  ///
  /// TODO(youngseokyoon): remove the embedded child builder logic from usps.
  /// https://fuchsia.atlassian.net/browse/SO-484
  void _addEmbeddedChildBuilders() {
    // USPS Tracking.
    log.fine("calling addEmbeddedChildBuilder('map')");
    kEmbeddedChildProvider.addEmbeddedChildBuilder(
      'map',
      (dynamic args) {
        log.fine('trying to launch map!');
        // Initialize the sub-module.
        ModuleControllerProxy moduleController = new ModuleControllerProxy();
        InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();

        log.fine('before startModule!');
        moduleContext.startModule(
          'map',
          _kMapModuleUrl,
          null, // Pass our default link down.
          null,
          null,
          moduleController.ctrl.request(),
          viewOwnerPair.passRequest(),
        );
        log.fine('after startModule!');

        InterfaceHandle<ViewOwner> viewOwner = viewOwnerPair.passHandle();
        ChildViewConnection conn = new ChildViewConnection(viewOwner);

        return new EmbeddedChild(
          widgetBuilder: (BuildContext context) {
            ChildView childView = new ChildView(connection: conn);
            log.fine('widgetBuilder call. conn: $conn, childView: $childView');
            return childView;
          },
          disposer: () {
            moduleController.stop(() {
              viewOwner.close();
              moduleController.ctrl.close();
            });
          },
          additionalData: <dynamic>[moduleController, conn],
        );
      },
    );
    log.fine("called addEmbeddedChildBuilder('map')");
  }

  /// Update Link with the given location.
  void updateLocation(String location) {
    log.fine('location is updated to: $location');

    Map<String, dynamic> mapDoc = <String, dynamic>{
      _kMapZoomkey: _kMapZoomValue,
      _kMapHeightKey: _kMapHeightValue,
      _kMapWidthKey: _kMapWidthValue,
      _kMapLocationKey: location,
    };

    link.updateObject(<String>[_kMapDocRoot], JSON.encode(mapDoc));
  }
}
