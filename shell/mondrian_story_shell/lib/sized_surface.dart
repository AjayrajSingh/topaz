// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'model.dart';

/// A class for passing Surfaces that have been sized by layout algorithm
class SizedSurface {
  /// The Surface
  final Surface surface;

  /// The size of the surface determined by layout algorithm
  final Rect rect;

  /// Dependency
  final SurfaceDependency dependency;

  /// Constructor
  SizedSurface({
    @required this.surface,
    @required this.rect,
    this.dependency: SurfaceDependency.dependent,
  });

  @override
  String toString() {
    return '${surface.toString()}| ${rect.toString()}';
  }
}
