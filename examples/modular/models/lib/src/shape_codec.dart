// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fuchsia_modular/entity.dart';

import 'shape.dart';

/// An [EntityCodec] which encodes and decodes a shape object
class ShapeCodec extends SimpleEntityCodec<Shape> {
  ShapeCodec()
      : super(
            type: 'com.fuchsia.shapes_mod.shape',
            encoding: '*',
            encode: _encode,
            decode: _decode);

  static Uint8List _encode(Shape shape) {
    final list = Uint8List(8);

    ByteData.view(list.buffer).setFloat64(0, shape.size);

    return list;
  }

  static Shape _decode(Uint8List list) {
    final size = ByteData.view(list.buffer).getFloat64(0);
    return Shape(size);
  }
}
