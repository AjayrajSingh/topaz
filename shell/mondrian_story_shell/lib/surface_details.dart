// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

/// A presentation arrangement in respect to another surface
enum SurfaceArrangement {
  /// No defined arrangement
  none,

  /// Should be copresented with other surface, if possible
  copresent
}

/// A presentation relationship with another surface
class SurfaceRelation {
  /// Const contructor
  const SurfaceRelation({this.arrangement: SurfaceArrangement.none});

  /// The arrangement relation to another surface
  final SurfaceArrangement arrangement;

  /// No relation to the other surface
  static const SurfaceRelation none = const SurfaceRelation();

  @override
  String toString() => 'arrangement:$arrangement';
}

/// Inherent properties of a surface
class SurfaceProperties {
  /// Const constructor
  const SurfaceProperties({this.constraints: const BoxConstraints()});

  /// No specified properties
  static const SurfaceProperties none = const SurfaceProperties();

  /// Recommended Min/Max size constraints
  final BoxConstraints constraints;
}
