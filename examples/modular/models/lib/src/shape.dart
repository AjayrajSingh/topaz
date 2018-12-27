// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// A Simple model object representing a shape
class Shape {
  static const String entityType = 'com.fuchsia.shapes_mod.shape';

  /// The size of the shape
  double size = 0.0;

  /// The maximum size of the shape
  final double maxSize = 10.0;

  /// The minimum size of the shape
  final double minSize = 0.0;

  /// The default constructor
  Shape(this.size);

  Shape.fromBytes(Uint8List bytes) {
    size = ByteData.view(bytes.buffer).getFloat64(0);
  }

  Uint8List toBytes() {
    final list = Uint8List(8);

    ByteData.view(list.buffer).setFloat64(0, size);

    return list;
  }
}
