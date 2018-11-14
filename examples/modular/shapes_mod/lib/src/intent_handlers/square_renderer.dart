// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example_modular_models/shape.dart';
import 'package:flutter/material.dart';

class SquareRenderer {
  void render(Stream<Shape> stream) {
    runApp(
      MaterialApp(
        home: Scaffold(
            body: Center(
          child: _makeSquare(stream),
        )),
      ),
    );
  }

  Widget _makeSquare(Stream<Shape> stream) => StreamBuilder<Shape>(
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
              shape: BoxShape.rectangle,
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
            ),
          ),
        );
      });
}
