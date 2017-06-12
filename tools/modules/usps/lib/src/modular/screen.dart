// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:widgets/usps.dart';

import 'module_model.dart';

/// The top level widget for the usps module.
class UspsScreen extends StatelessWidget {
  /// The USPS api key.
  final String apiKey;

  /// Creates a new instance of [UspsScreen].
  UspsScreen({
    Key key,
    @required this.apiKey,
  })
      : super(key: key) {
    assert(apiKey != null);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'USPS Tracking',
      home: new ScopedModelDescendant<UspsModuleModel>(
        builder: (_, __, UspsModuleModel model) {
          return new Material(
            color: Colors.white,
            child: new Container(
              alignment: FractionalOffset.center,
              constraints: const BoxConstraints.expand(),
              color: Colors.white,
              child: new Container(
                constraints: const BoxConstraints.expand(),
                child: model.trackingCode != null && apiKey != null
                    ? new TrackingStatus(
                        trackingCode: model.trackingCode,
                        apiKey: apiKey,
                        onLocationSelect: (String location) {
                          log.fine('selecting location: $location');
                          model.updateLocation(location);
                        })
                    : new Text(
                        'Error: either _trackingCode or _apiKey is null. '
                        'Please check if you have "usps_api_key" in your'
                        'config.json file.'),
              ),
            ),
          );
        },
      ),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
