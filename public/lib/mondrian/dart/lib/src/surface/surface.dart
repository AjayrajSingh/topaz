// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Details of a surface view
class Surface {
  /// Public constructor
  Surface({this.surfaceId, this.metadata});

  /// This Surface in the graph
  final String surfaceId;

  /// The metadata related to this Surface (including minWidth)
  // TODO (djmurphy): this is placeholder and needs some further thinking.
  final Map<String, String> metadata;

  @override
  String toString() {
    return '$Surface $surfaceId';
  }
}
