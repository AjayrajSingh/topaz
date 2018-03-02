// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// import 'dart:math';

import 'package:flutter/widgets.dart';

import 'layout_model.dart';
import 'model.dart';
import 'positioned_surface.dart';

const String _tickerPattern = 'ticker';
const String _commentsRightPattern = 'comments_right';

const double _tickerHeightRatio = 0.15;
const double _commentsWidthRatio = 0.30;

/// Returns in the order they should stacked
List<PositionedSurface> layoutSurfaces(
  BuildContext context,
  BoxConstraints constraints,
  List<Surface> focusStack,
  LayoutModel layoutModel,
) {
  if (focusStack.isEmpty) {
    return <PositionedSurface>[];
  }
  Surface focused = focusStack.last;
  String pattern = focused.compositionPattern;

  final double totalWidth = constraints.biggest.width;
  final double totalHeight = constraints.biggest.height;

  final List<PositionedSurface> layout = <PositionedSurface>[];

  // TODO(jphsiao): Handle new children that are brought in
  Surface parent = focused.parent;

  Offset offset = Offset.zero;
  if (parent == null) {
    Size size = new Size(
      totalWidth,
      totalHeight,
    );
    layout
        .add(new PositionedSurface(surface: focused, position: offset & size));
  } else if (pattern == _tickerPattern) {
    // TODO(jphsiao): Match the parent's width
    double tickerHeight = totalHeight * _tickerHeightRatio;

    Size size = new Size(
      totalWidth,
      totalHeight - tickerHeight,
    );
    layout.add(new PositionedSurface(surface: parent, position: offset & size));
    offset += size.bottomLeft(Offset.zero);

    size = new Size(
      totalWidth,
      tickerHeight,
    );
    layout
        .add(new PositionedSurface(surface: focused, position: offset & size));
  } else if (pattern == _commentsRightPattern) {
    // TODO(jphsiao): Determine proper height of the parent and comments
    double commentsWidth = totalWidth * _commentsWidthRatio;

    Size size = new Size(
      totalWidth - commentsWidth,
      totalHeight,
    );
    layout.add(new PositionedSurface(surface: parent, position: offset & size));
    offset += size.topRight(Offset.zero);

    size = new Size(
      commentsWidth,
      totalHeight,
    );
    layout
        .add(new PositionedSurface(surface: focused, position: offset & size));
  }
  return layout;
}
