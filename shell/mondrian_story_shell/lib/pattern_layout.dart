// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';

import 'layout_model.dart';
import 'model.dart';
import 'positioned_surface.dart';

const String _parentId = 'parent';
const String _tickerPattern = 'ticker';
const String _commentsRightPattern = 'comments-right';

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

  final double totalWidth = constraints.biggest.width;
  final double totalHeight = constraints.biggest.height;
  final List<PositionedSurface> layout = <PositionedSurface>[];
  Surface focused = focusStack.last;
  String pattern = focused.compositionPattern;

  if (!_isSupportedPattern(pattern)) {
    log.warning('unrecognized pattern $pattern');

    Size size = new Size(
      totalWidth,
      totalHeight,
    );
    layout.add(
        new PositionedSurface(surface: focused, position: Offset.zero & size));
    return layout;
  }

  Map<String, Surface> patternSurfaces = <String, Surface>{};
  // This is really a list not a stack. Reverse it to get to the 'top' items first.
  for (Surface surface in focusStack.reversed) {
    if (surface.compositionPattern != null) {
      String pattern = surface.compositionPattern;
      patternSurfaces.putIfAbsent(pattern, () => surface);
    } else {
      // TODO (jphsiao): Once we have better signals for figuring out which module
      // to compose the pattern module with we can identify the 'source' more definitively.
      // For now, the surface without a pattern is likely the source.
      patternSurfaces.putIfAbsent(_parentId, () => surface);
    }
  }

  if (patternSurfaces.containsKey(_commentsRightPattern)) {
    // Comments-right gets laid out first
    _layoutCommentsRight(patternSurfaces[_parentId],
            patternSurfaces[_commentsRightPattern], totalHeight, totalWidth)
        .forEach(layout.add);
  }
  if (patternSurfaces.containsKey(_tickerPattern)) {
    double availableWidth = totalWidth;
    double availableHeight = totalHeight;
    if (layout.isNotEmpty && layout[0].surface == patternSurfaces[_parentId]) {
      availableHeight = layout[0].position.height;
      availableWidth = layout[0].position.width;
    }
    List<PositionedSurface> tickerSurfaces = _layoutTicker(
        patternSurfaces[_parentId],
        patternSurfaces[_tickerPattern],
        availableHeight,
        availableWidth);
    if (layout.isNotEmpty) {
      layout[0] = tickerSurfaces[0];
    } else {
      layout.add(tickerSurfaces[0]);
    }
    layout.add(tickerSurfaces[1]);
  }
  return layout;
}

bool _isSupportedPattern(String pattern) {
  return (pattern == _tickerPattern || pattern == _commentsRightPattern);
}

List<PositionedSurface> _layoutTicker(Surface tickerSource, Surface ticker,
    double availableHeight, double availableWidth) {
  List<PositionedSurface> layout = <PositionedSurface>[];
  Offset offset = Offset.zero;
  double tickerHeight = availableHeight * _tickerHeightRatio;

  Size size = new Size(
    availableWidth,
    availableHeight - tickerHeight,
  );
  layout.add(
      new PositionedSurface(surface: tickerSource, position: offset & size));
  offset += size.bottomLeft(Offset.zero);

  size = new Size(
    availableWidth,
    tickerHeight,
  );
  layout.add(new PositionedSurface(surface: ticker, position: offset & size));
  return layout;
}

List<PositionedSurface> _layoutCommentsRight(Surface commentsSource,
    Surface comments, double availableHeight, double availableWidth) {
  List<PositionedSurface> layout = <PositionedSurface>[];
  Offset offset = Offset.zero;
  double commentsWidth = availableWidth * _commentsWidthRatio;

  Size size = new Size(
    availableWidth - commentsWidth,
    availableHeight,
  );
  layout.add(
      new PositionedSurface(surface: commentsSource, position: offset & size));
  offset += size.topRight(Offset.zero);

  size = new Size(
    commentsWidth,
    availableHeight,
  );
  layout.add(new PositionedSurface(surface: comments, position: offset & size));
  return layout;
}
