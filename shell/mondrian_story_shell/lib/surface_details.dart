// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

/// Inherent properties of a surface
class SurfaceProperties {
  /// Const constructor
  const SurfaceProperties({this.constraints: const BoxConstraints()});

  /// No specified properties
  static const SurfaceProperties none = const SurfaceProperties();

  /// Recommended Min/Max size constraints
  final BoxConstraints constraints;
}
