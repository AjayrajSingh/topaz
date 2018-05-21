// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/widgets.dart';

import 'layout_model.dart';
import 'model.dart';
import 'positioned_surface.dart';
import 'tree.dart';

// Convenience comparator used to ensure more focused items get higher priority
int _compareByOtherList(Surface l, Surface r, List<Surface> otherList) {
  int li = otherList.indexOf(l);
  int ri = otherList.indexOf(r);
  if (li < 0) {
    li = otherList.length;
  }
  if (ri < 0) {
    ri = otherList.length;
  }
  return ri - li;
}

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

  final double totalWidth = constraints.biggest.width;
  final double screenWidth =
      context != null ? MediaQuery.of(context).size.width : totalWidth;
  final double absoluteMinWidth = max(
    screenWidth * layoutModel.minScreenRatio,
    layoutModel.minScreenWidth,
  );
  Tree<Surface> copresTree = focused.copresentSpanningTree;

  int focusOrder(Tree<Surface> l, Tree<Surface> r) =>
      _compareByOtherList(l.value, r.value, focusStack);

  // Remove dismissed surfaces and collapse tree
  for (Tree<Surface> node in copresTree) {
    if (node.value.dismissed) {
      node.children.forEach(node.parent.add);
      node.detach();
    }
  }

  // Prune less focused surfaces where their min constraints do not fit
  double totalMinWidth = 0.0;
  for (Tree<Surface> node
      in copresTree.flatten(orderChildren: focusOrder).skipWhile(
    (Tree<Surface> node) {
      double minWidth = node.value.minWidth(min: absoluteMinWidth);
      if (totalMinWidth + minWidth > totalWidth) {
        return false;
      }
      totalMinWidth += minWidth;
      return true;
    },
  )) {
    node.detach();
  }

  // Prune less focused surfaces where emphasis values cannot be respected
  double totalEmphasis = 0.0;
  Surface top = focused;
  Surface tightestFit = focused;
  for (Tree<Surface> node
      in copresTree.flatten(orderChildren: focusOrder).skipWhile(
    (Tree<Surface> node) {
      Surface prevTop = top;
      double prevTotalEmphasis = totalEmphasis;

      // Update top
      if (top.ancestors.contains(node.value)) {
        top = node.value;
        totalEmphasis *= prevTop.absoluteEmphasis(top);
      }
      double emphasis = node.value.absoluteEmphasis(top);
      totalEmphasis += emphasis;

      // Calculate min width available
      double tightestFitEmphasis = tightestFit.absoluteEmphasis(top);
      double extraWidth = emphasis / totalEmphasis * totalWidth -
          node.value.minWidth(min: absoluteMinWidth);
      double tightestFitExtraWidth =
          tightestFitEmphasis / totalEmphasis * totalWidth -
              tightestFit.minWidth(min: absoluteMinWidth);

      // Break if smallest or this doesn't fit
      if (min(tightestFitExtraWidth, extraWidth) < 0.0) {
        // Restore previous values
        top = prevTop;
        totalEmphasis = prevTotalEmphasis;
        return false;
      }

      // Update tightest fit
      if (extraWidth < tightestFitExtraWidth) {
        tightestFit = node.value;
      }
      return true;
    },
  )) {
    node.detach();
  }

  List<Surface> surfacesToDisplay =
      copresTree.map((Tree<Surface> t) => t.value).toList(growable: false);

  Iterable<Surface> arrangement =
      top.flattened.where((Surface s) => surfacesToDisplay.contains(s));

  // Layout rects for arrangement
  final List<PositionedSurface> layout = <PositionedSurface>[];
  final double totalHeight = constraints.biggest.height;
  Offset offset = Offset.zero;
  for (Surface surface in arrangement) {
    Size size = new Size(
      surface.absoluteEmphasis(top) / totalEmphasis * totalWidth,
      totalHeight,
    );
    layout
        .add(new PositionedSurface(surface: surface, position: offset & size));
    offset += size.topRight(Offset.zero);
  }
  return layout;
}
