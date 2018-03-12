// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'modular/module_model.dart';

/// Custom painter for that draws the square
class SquarePainter extends CustomPainter {
  final Color _color;
  double _scale;
  double _radians;

  SquarePainter(this._color, this._scale, this._radians);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the square in the center of the canvas.
    double edge = size.shortestSide / 2.0;
    double x0 = size.width / 2.0;
    double y0 = size.height / 2.0;
    canvas
      ..translate(x0, y0)
      ..rotate(_radians)
      ..scale(_scale, _scale)
      ..drawRect(
        new Rect.fromLTWH(-edge / 2.0, -edge / 2.0, edge, edge),
        new Paint()..color = _color,
      );
  }

  @override
  bool shouldRepaint(SquarePainter oldDelegate) =>
      oldDelegate._color != _color ||
      oldDelegate._scale != _scale ||
      oldDelegate._radians != _radians;

  @override
  bool hitTest(Offset position) => false;
}

class BLERectScreen extends StatelessWidget {
  Widget _bottomText(BLERectModuleModel model) {
    if (model.lastStatus?.error != null) {
      return new Text('Error: ${model.lastStatus.error.description}',
          style: const TextStyle(color: const Color(0xFFFFC0EB)));
    }

    if (!model.isCentralConnected) {
      return new Row(children: <Widget>[
        const Text('Waiting for connection...'),
        const CircularProgressIndicator(),
      ]);
    }

    // TODO(armansito): Show name here instead when we perform name discovery on
    // centrals.
    return new Align(
        alignment: Alignment.centerLeft,
        child: new Text('Connected: ${model.connectedCentralId}'));
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<BLERectModuleModel>(builder: (
      BuildContext context,
      Widget child,
      BLERectModuleModel model,
    ) {
      return new Scaffold(
          appBar: new AppBar(
              title: const Text('BLE Rect'),
              bottom: new PreferredSize(
                  child: new Container(
                      color: Colors.white, child: _bottomText(model)),
                  preferredSize: const Size.fromHeight(10.0))),
          body: model.isCentralConnected
              ? new RepaintBoundary(
                  child: new CustomPaint(
                      child: new Container(),
                      painter: new SquarePainter(
                          model.color, model.scale, model.radians)))
              : new Container(color: Colors.grey));
    });
  }
}
