// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// ignore_for_file: public_member_api_docs

// Hosts a Scenic scene graph, in a very naive way.
class ScenicWidget extends LeafRenderObjectWidget {
  const ScenicWidget(this.sceneHost);

  final SceneHost sceneHost;

  @override
  _RenderBox createRenderObject(BuildContext context) {
    return new _RenderBox(sceneHost);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBox renderObject) {}
}

class _RenderBox extends RenderBox {
  _RenderBox(this.sceneHost);

  final SceneHost sceneHost;

  double _width;
  double _height;

  @override
  void performLayout() {
    size = constraints.biggest;

    if (_width != size.width || _height != size.height) {
      // TODO: layout invalidation?
      _width = size.width;
      _height = size.height;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.addLayer(new _Layer(
        offset: offset,
        width: _width,
        height: _height,
        sceneHost: sceneHost,
        hitTestable: false));
  }
}

class _Layer extends Layer {
  _Layer({
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
  S find<S>(Offset regionOffset) => null;
}
