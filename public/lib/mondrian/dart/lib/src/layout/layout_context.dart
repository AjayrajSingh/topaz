// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The context in which the Composer determines layout
class LayoutContext {
  /// The size of the viewport the Composer can use
  final Size size;

  /// Constructor
  const LayoutContext({this.size});
}

/// Simple class for capturing 2D size of boxes in layout.
class Size {
  /// height
  final int height;

  /// width
  final int width;

  /// constructor
  const Size(this.width, this.height);

  /// convert to JSON
  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
      };
}
