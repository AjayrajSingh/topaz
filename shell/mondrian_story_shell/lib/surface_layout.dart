// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'model.dart';
import 'surface_widget.dart';
import 'tree.dart';

const double _kMinScreenWidth = 250.0;
const double _kMinScreenRatio = 1.0 / 4.0;

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  /// SurfaceLayout
  SurfaceLayout({Key key}) : super(key: key);

  @override
  _SurfaceLayoutState createState() => new _SurfaceLayoutState();
}

/// Maintains state for the avaialble views to display.
class _SurfaceLayoutState extends State<SurfaceLayout> {
  /// Surfaces currently animating away
  final Map<Surface, Rect> activeSurfaces = new Map<Surface, Rect>();

  /// Surfaces currently being directly manipulated by user
  final List<Surface> touchedSurfaces = new List<Surface>();

  /// Layout offset
  double offset = 0.0;

  void _startDrag(Surface surface, SimulatedDragStartDetails details) {
    if (!touchedSurfaces.contains(surface)) {
      setState(() {
        touchedSurfaces.add(surface);
      });
    }
  }

  void _endDrag(Surface surface, Rect rect, SimulatedDragEndDetails details) {
    // TODO(alangardner): Remove from touched list AFTER finished animating
    // In order to prevent surfaces from passing through each other
    touchedSurfaces.remove(surface);
    // HACK(alangardner): Harcoded distances for swipe gesture
    // to avoid complicated layout work for this throwaway version.
    Offset expectedOffset =
        details.offset + (details.velocity.pixelsPerSecond / 5.0);
    // Only remove if greater than threshold ant not root surface.
    if (expectedOffset.distance > 200.0) {
      setState(() {
        surface.dismiss();
      });
    }
  }

  // A surface that can be manipulated and interacted with by the user
  Widget _activeSurface({
    Surface surface,
    Rect rect,
    Rect initRect,
  }) =>
      new SimulatedPositioned(
        key: new GlobalObjectKey(surface),
        rect: rect,
        initRect: initRect,
        draggable: true,
        child: new ScopedModel<Surface>(
          model: surface,
          child: new SurfaceWidget(),
        ),
        onDragStart: (SimulatedDragStartDetails details) {
          _startDrag(surface, details);
        },
        onDragEnd: (SimulatedDragEndDetails details) {
          _endDrag(surface, rect, details);
        },
        dragOffsetTransform: surface.canDismiss()
            ? null
            : (Offset currentOffset, DragUpdateDetails details) {
                double scale = max(1.0, currentOffset.distanceSquared / 100.0);
                return details.delta / scale;
              },
      );

  // A surface that cannot be manipulated or interacted with by the user
  Widget _inactiveSurface(
          {Surface surface, Rect rect, Rect initRect, int distance = 0}) =>
      new SimulatedPositioned(
        key: new GlobalObjectKey(surface),
        rect: rect,
        initRect: initRect,
        draggable: false,
        child: new ScopedModel<Surface>(
          model: surface,
          child: new SurfaceWidget(
              interactable: false, fade: max(0.0, min(distance * 0.5, 1.0))),
        ),
      );

  // Convenience comparator used to ensure more focued items get higher priority
  static int _compareByOtherList(
      Surface l, Surface r, List<Surface> otherList) {
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

  // Returns ordered map of an arrangement of surfaces that fit constraints
  Map<Surface, Rect> _layout(
    BoxConstraints constraints,
    List<Surface> focusStack,
  ) {
    assert(focusStack != null && focusStack.isNotEmpty);
    Surface focused = focusStack.last;

    final double totalWidth = constraints.biggest.width;
    final double absoluteMinWidth = max(
        MediaQuery.of(context).size.width * _kMinScreenRatio, _kMinScreenWidth);
    Tree<Surface> copresTree = focused.copresentSpanningTree;

    dynamic focusOrder = (Tree<Surface> l, Tree<Surface> r) =>
        _compareByOtherList(l.value, r.value, focusStack);

    // Remove dismissed surfaces and collapse tree
    copresTree.forEach((Tree<Surface> node) {
      if (node.value.dismissed) {
        node.children.forEach((Tree<Surface> child) {
          node.parent.add(child);
        });
        node.detach();
      }
    });

    // Prune less focused surfaces where their min constraints do not fit
    double totalMinWidth = 0.0;
    copresTree
        .flatten(orderChildren: focusOrder)
        .skipWhile((Tree<Surface> node) {
      double minWidth = node.value.minWidth(min: absoluteMinWidth);
      if (totalMinWidth + minWidth > totalWidth) {
        return false;
      }
      totalMinWidth += minWidth;
      return true;
    }).forEach((Tree<Surface> node) => node.detach());

    // Prune less focused surfaces where emphasis values cannot be respected
    double totalEmphasis = 0.0;
    Surface top = focused;
    Surface tightestFit = focused;
    copresTree
        .flatten(orderChildren: focusOrder)
        .skipWhile((Tree<Surface> node) {
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
    }).forEach((Tree<Surface> node) => node.detach());

    List<Surface> surfacesToDisplay =
        copresTree.map((Tree<Surface> t) => t.value).toList(growable: false);

    Iterable<Surface> arrangement =
        top.flattened.where((Surface s) => surfacesToDisplay.contains(s));

    // Layout rects for arrangement
    final Map<Surface, Rect> layout = new LinkedHashMap<Surface, Rect>();
    final double totalHeight = constraints.biggest.height;
    Offset offset = Offset.zero;
    for (Surface surface in arrangement) {
      Size size = new Size(
        surface.absoluteEmphasis(top) / totalEmphasis * totalWidth,
        totalHeight,
      );
      layout[surface] = offset & size;
      offset += size.topRight(Offset.zero);
    }
    return layout;
  }

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          new ScopedModelDescendant<SurfaceGraph>(builder:
              (BuildContext context, Widget child, SurfaceGraph graph) {
            if (constraints.biggest.isInfinite) {
              _log('WARNING: Infinite sized constraints. $constraints');
              return new Container();
            } else if (constraints.biggest.isEmpty) {
              return new Container();
            }
            final List<Widget> childViews = <Widget>[];

            final Rect full = Offset.zero & constraints.biggest;
            final Offset topLeft = Offset.zero;
            final Offset offscreen = constraints.biggest.topRight(topLeft);

            final List<Widget> touchedSurfaceWidgets = <Widget>[];
            final Map<Surface, Rect> laidOut = new Map<Surface, Rect>();

            if (graph.focusStack.isNotEmpty) {
              List<Surface> focusStack = graph.focusStack.toList();
              Map<Surface, Rect> layout = _layout(constraints, focusStack);
              // If for some reason nothing fits, full screen focused
              if (layout.isEmpty) {
                layout[focusStack.last] = full;
              }
              // Take second most focused and repeat layout algorithm
              // Add any unlaid out and add them to background
              laidOut.addAll(layout);
              focusStack.removeLast();
              int distance = 1;
              while (focusStack.isNotEmpty) {
                Map<Surface, Rect> backgroundLayout =
                    _layout(constraints, focusStack);
                laidOut.keys.forEach((Surface s) => backgroundLayout.remove(s));
                laidOut.addAll(backgroundLayout);
                if (backgroundLayout.isNotEmpty) {
                  List<Widget> backgroundChildViews = <Widget>[];
                  backgroundLayout.forEach((Surface s, Rect rect) {
                    // TODO(alangardner): Ensure a proper order
                    backgroundChildViews.add(_inactiveSurface(
                      surface: s,
                      rect: rect,
                      initRect: offscreen & rect.size,
                      distance: distance,
                    ));
                  });
                  childViews.insertAll(0, backgroundChildViews);

                  distance += 1;
                }
                focusStack.removeLast();
              }

              layout.forEach((Surface s, Rect rect) {
                // TODO(alangardner): Ensure a proper order
                Widget surfaceWidget = _activeSurface(
                  surface: s,
                  rect: rect,
                  initRect: offscreen & rect.size,
                );
                if (touchedSurfaces.contains(s)) {
                  touchedSurfaceWidgets.add(surfaceWidget);
                } else {
                  childViews.add(surfaceWidget);
                }
              });
            }

            // Animating out surfaces
            laidOut.forEach((Surface s, Rect r) => activeSurfaces.remove(s));
            activeSurfaces.forEach((Surface surface, Rect rect) {
              childViews.add(_inactiveSurface(
                surface: surface,
                rect: offscreen & rect.size,
              ));
            });

            // Draw touched surfaces on top, with first touched on top
            childViews.addAll(touchedSurfaceWidgets);

            activeSurfaces.addAll(laidOut);

            return new Stack(children: childViews);
          }));
}
