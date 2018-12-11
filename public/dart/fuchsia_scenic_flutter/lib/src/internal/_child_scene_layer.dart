// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';
import 'package:flutter/rendering.dart';

/// A layer that represents content from another process.
class ChildSceneLayer extends Layer {
  /// Creates a layer that displays content rendered by another process.
  ///
  /// All of the arguments must not be null.
  ChildSceneLayer({
    this.offset = Offset.zero,
    this.width = 0.0,
    this.height = 0.0,
    this.sceneHost,
    this.hitTestable = true,
  });

  /// Offset from parent in the parent's coordinate system.
  Offset offset;

  /// The horizontal extent of the child, in logical pixels.
  double width;

  /// The vertical extent of the child, in logical pixels.
  double height;

  /// The host site for content rendered by the child.
  SceneHost sceneHost;

  /// Whether this child should be included during hit testing.
  ///
  /// Defaults to true.
  bool hitTestable;

  @override
  EngineLayer addToScene(SceneBuilder builder,
      [Offset layerOffset = Offset.zero]) {
    builder.addChildScene(
      offset: offset + layerOffset,
      width: width,
      height: height,
      sceneHost: sceneHost,
      hitTestable: hitTestable,
    );
    return null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
      ..add(DiagnosticsProperty<Offset>('offset', offset))
      ..add(DoubleProperty('width', width))
      ..add(DoubleProperty('height', height))
      ..add(DiagnosticsProperty<SceneHost>('sceneHost', sceneHost))
      ..add(DiagnosticsProperty<bool>('hitTestable', hitTestable));
  }

  @override
  S find<S>(Offset regionOffset) => null;
}
