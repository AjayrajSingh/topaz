// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'location_details_module_model.dart';

/// The top level widget for the location details module
class LocationsDetailModuleScreen extends StatelessWidget {
  /// Constructor
  LocationsDetailModuleScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new ScopedModelDescendant<LocationDetailsModuleModel>(builder: (
        BuildContext context,
        Widget child,
        LocationDetailsModuleModel model,
      ) {
        List<Widget> embeds = <Widget>[];
        if (model.mapViewConn != null) {
          embeds.add(new Container(
            height: 250.0,
            width: 250.0,
            child: new ChildView(connection: model.mapViewConn),
          ));
        }
        if (model.forecastViewConn != null) {
          embeds.add(new Container(
            height: 130.0,
            width: 250.0,
            child: new ChildView(connection: model.forecastViewConn),
          ));
        }
        if (model.travelInfoViewConn != null) {
          embeds.add(new Container(
            height: 140.0,
            width: 250.0,
            child: new ChildView(connection: model.travelInfoViewConn),
          ));
        }
        return new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: embeds,
        );
      }),
    );
  }
}
