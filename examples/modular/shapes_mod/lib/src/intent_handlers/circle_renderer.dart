// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example_modular_models/shape.dart';
import 'package:flutter/material.dart';

class CircleRenderer {
  void render(Stream<Shape> stream) {
    runApp(
      MaterialApp(
        home: Scaffold(
            body: Center(
          child: _makeCircle(stream),
        )),
      ),
    );
  }

  Widget _makeCircle(Stream<Shape> stream) => StreamBuilder<Shape>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<Shape> snapshot) {
        final shape = snapshot.data;
        if (shape == null) {
          return Container(
            color: Colors.pink,
          );
        }

        final scale = shape.size / (shape.maxSize - shape.minSize);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.pink,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green,
                width: snapshot.data.size,
              ),
            ),
          ),
        );
      });
}
