// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:widgets/map.dart';

import 'module_model.dart';

/// The top level widget for the map module.
class MapScreen extends StatelessWidget {
  /// The Google api key.
  final String apiKey;

  /// Creates a new instance of [MapScreen].
  MapScreen({
    Key key,
    @required this.apiKey,
  })
      : super(key: key) {
    assert(apiKey != null);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Map',
      home: new ScopedModelDescendant<MapModuleModel>(
        builder: (_, __, MapModuleModel model) {
          return new Container(
            alignment: FractionalOffset.center,
            constraints: const BoxConstraints.expand(),
            child: model.mapLocation != null && apiKey != null
                ? new StaticMap(
                    location: model.mapLocation,
                    zoom: model.mapZoom,
                    width: model.mapWidth,
                    height: model.mapHeight,
                    apiKey: apiKey,
                  )
                : new CircularProgressIndicator(),
          );
        },
      ),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
