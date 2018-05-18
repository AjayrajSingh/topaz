// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

/// Inherent properties of a surface
class SurfaceProperties {
  /// Const constructor
  SurfaceProperties(
      {this.constraints = const BoxConstraints(), this.containerLabel});

  /// Recommended Min/Max size constraints
  final BoxConstraints constraints;

  /// Belongs to a container with label containerLabel
  String containerLabel;

  /// List of the containers this Surface is a member of
  /// (To be able to support container-to-container transitions)
  /// The container this Surface is currently participating in is
  /// end of list. If this Surface is focused, that is the container that
  /// will be laid out.
  List<String> containerMembership;
}
