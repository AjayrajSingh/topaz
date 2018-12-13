// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';

const List<Color> _colors = const <Color>[
  Colors.red,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.blue,
  Colors.indigo,
  Colors.purple,
];
const double _elevationMultiplier = 6;
const int _numTotalLayers = 7;
const double _sizeMultiplier = 60;

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) {
    // Note that this mod does not care about intent.
    runApp(
      MaterialApp(
        title: 'Multilevel Mod',
        home: Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Stack(
                alignment: const Alignment(0.0, 0.0),
                children: _createLayers(_numTotalLayers)),
          ),
        ),
      ),
    );
  }

  // Helper function to create list of concentric Material widgets.
  List<Widget> _createLayers(int totalLayers) {
    var layers = <Widget>[];
    for (var i = 0; i < totalLayers; i++) {
      // Elevation in descending order to demonstrate how flutter renders in
      // elevation, not stack order.
      double elevation =
          (totalLayers * _elevationMultiplier) - (i * _elevationMultiplier);
      Color color = _colors[i % _colors.length];
      double sideLength = (i + 1).toDouble() * _sizeMultiplier;
      layers.add(_makeLayer(elevation, color, sideLength, sideLength));
    }
    return layers;
  }

  // Helper function to create Material layer with specified elevation, color,
  // and size. Includes text describing the elevation of the material.
  Widget _makeLayer(
      double elevation, Color color, double height, double width) {
    return Material(
      elevation: elevation,
      child: Container(
        color: color,
        height: height,
        width: width,
        child: Text((elevation).toString(),
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
