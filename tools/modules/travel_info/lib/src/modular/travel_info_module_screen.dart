// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:widgets/common.dart';
import 'package:widgets/map.dart';

import 'travel_info_module_model.dart';

/// The top level widget for the weather forecast
class TravelInfoModuleScreen extends StatelessWidget {
  /// Constructor
  TravelInfoModuleScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.white,
      body: new ScopedModelDescendant<TravelInfoModuleModel>(builder: (
        BuildContext context,
        Widget child,
        TravelInfoModuleModel model,
      ) {
        switch (model.loadingStatus) {
          case LoadingStatus.completed:
            return new Center(
              child: new TravelInfoCard(
                travelInfo: model.travelInfo,
              ),
            );
          case LoadingStatus.failed:
            return new Container(
              child: new Center(
                child: new Column(
                  children: <Widget>[
                    new Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: new Icon(
                        Icons.sentiment_dissatisfied,
                        size: 48.0,
                        color: Colors.grey[500],
                      ),
                    ),
                    new Text(
                      'Content failed to load',
                      style: new TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          case LoadingStatus.inProgress:
          default:
            return new Container(
              child: new Center(
                child: new Container(
                  height: 40.0,
                  width: 40.0,
                  child: new FuchsiaSpinner(),
                ),
              ),
            );
        }
      }),
    );
  }
}
