// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A Simple model object representing a shape
class Shape {
  /// The size of the shape
  double size = 0.0;

  /// The maximum size of the shape
  final double maxSize = 10.0;

  /// The minimum size of the shape
  final double minSize = 0.0;

  /// The default constructor
  Shape(this.size);
}
