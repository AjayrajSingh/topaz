// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'model.dart';
import 'simulated_positioned.dart';
import 'surface_widget.dart';
import 'tree.dart';

const double _kMinScreenWidth = 300.0;
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
  Map<Surface, Size> removedSurfaces = new Map<Surface, Size>();

  /// Surfaces currently being directly manipulated by user
  List<Surface> touchedSurfaces = new List<Surface>();

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
        if (surface.remove()) {
          removedSurfaces[surface] = rect.size;
        }
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
        key: new ObjectKey(surface),
        rect: rect,
        initRect: initRect,
        draggable: true,
        child: new ScopedModel<Surface>(
            model: surface, child: new SurfaceWidget()),
        onDragStart: (SimulatedDragStartDetails details) {
          _startDrag(surface, details);
        },
        onDragEnd: (SimulatedDragEndDetails details) {
          _endDrag(surface, rect, details);
        },
      );

  // A surface that cannot be manipulated or interacted with by the user
  Widget _inactiveSurface({Surface surface, Rect rect, Rect initRect}) =>
      new SimulatedPositioned(
        key: new ObjectKey(surface),
        rect: rect,
        initRect: initRect,
        draggable: false,
        child: new ScopedModel<Surface>(
          model: surface,
          child: new SurfaceWidget(interactable: false),
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
    if (focusStack.isEmpty) {
      return new Map<Surface, Rect>();
    }
    Surface focused = focusStack.last;

    // Crawl through surfaces' parent and children
    // and put equally distant relatives in focus order
    List<Surface> related = <Surface>[];
    Iterable<Tree<Surface>> descendents = <Tree<Surface>>[
      focused.copresentSpanningTree
    ];
    while (descendents.isNotEmpty) {
      List<Surface> copresSurfaces =
          descendents.map((Tree<Surface> n) => n.value).toList();
      // Ensure more focused items get higher priority
      copresSurfaces.sort(
          (Surface l, Surface r) => _compareByOtherList(l, r, focusStack));
      related.addAll(copresSurfaces);
      descendents = descendents.expand((Tree<Surface> n) => n.children);
    }

    List<Surface> arrangement = <Surface>[];
    final double maxWidth = constraints.biggest.width;
    Iterable<Surface> ancestors = focused.ancestors;
    final double absoluteMinWidth = max(
        MediaQuery.of(context).size.width * _kMinScreenRatio, _kMinScreenWidth);
    double arrangementWidth = arrangement.fold(
        0.0,
        (double width, Surface s) =>
            width +
            max(s.properties?.constraints?.minWidth ?? 0.0, absoluteMinWidth));
    for (Surface surface in related) {
      double minWidth = max(
          surface.properties?.constraints?.minWidth ?? 0.0, absoluteMinWidth);
      if (arrangementWidth + minWidth > maxWidth) {
        break;
      }
      // Adding each to the left (ancestor) or right (descendent)
      if (arrangement.isEmpty) {
        arrangement.add(surface);
      } else if (ancestors.contains(surface)) {
        arrangement.insert(0, surface);
      } else {
        // Maintain stability of sibling order to prevent unecessary movement
        List<Surface> siblings =
            surface.parent?.children?.toList(growable: false);
        if (siblings == null || siblings.length == 1) {
          arrangement.add(surface);
        } else {
          for (Surface arranged in arrangement.reversed) {
            if (_compareByOtherList(arranged, surface, siblings) < 0) {
              arrangement.insert(arrangement.indexOf(arranged) + 1, surface);
              break;
            }
          }
        }
      }
      arrangementWidth += minWidth;
    }

    final Map<Surface, Rect> layout = new LinkedHashMap<Surface, Rect>();
    final double totalWidth = constraints.biggest.width;
    final double totalHeight = constraints.biggest.height;
    final double minWidth = arrangement.fold(0.0,
        (double width, Surface s) => width + s.properties.constraints.minWidth);
    final double extraWidth = (totalWidth - minWidth) / arrangement.length;
    Offset offset = Offset.zero;
    for (Surface surface in arrangement) {
      Size size = new Size(
        surface.properties.constraints.minWidth + extraWidth,
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
            final List<Widget> childViews = <Widget>[];

            final Rect full = Offset.zero & constraints.biggest;
            final Offset topLeft = Offset.zero;
            final Offset offscreen = constraints.biggest.topRight(topLeft);

            final List<Widget> touchedSurfaceWidgets = <Widget>[];

            if (graph.size == 0) {
              childViews.add(new MondrianSpinner());
            } else if (graph.size == 1) {
              _log('BUILD chromeless HACK');
              Surface sole = graph.focusStack.last;
              childViews.add(new SimulatedPositioned(
                key: new ObjectKey(sole),
                rect: full,
                draggable: false,
                child: new ScopedModel<Surface>(
                  model: sole,
                  child: new SurfaceWidget(chrome: false),
                ),
              ));
            } else {
              List<Surface> focusStack = graph.focusStack.toList();
              Map<Surface, Rect> layout = _layout(constraints, focusStack);
              // If for some reason nothing fits, full screen focused
              if (layout.isEmpty) {
                layout[focusStack.last] = full;
              }
              // Take second most focused and repeat layout algorithm
              // Add any unlaid out and add them to background
              List<Surface> laidOut = layout.keys.toList();
              focusStack.removeLast();
              while (focusStack.isNotEmpty) {
                List<Widget> backgroundChildViews = <Widget>[];
                Map<Surface, Rect> backgroundLayout =
                    _layout(constraints, focusStack);
                laidOut.forEach((Surface s) => backgroundLayout.remove(s));
                laidOut.addAll(backgroundLayout.keys);
                if (backgroundLayout.isNotEmpty) {
                  backgroundLayout.forEach((Surface s, Rect rect) {
                    // TODO(alangardner): Ensure a proper order
                    backgroundChildViews.add(_inactiveSurface(
                      surface: s,
                      rect: rect,
                      initRect: offscreen & rect.size,
                    ));
                  });
                  // Add scrim
                  backgroundChildViews.add(new Container(
                    constraints: constraints,
                    color: const Color(0x44000000),
                  ));
                  childViews.insertAll(0, backgroundChildViews);
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
            removedSurfaces.forEach((Surface surface, Size size) {
              childViews.add(_inactiveSurface(
                surface: surface,
                rect: offscreen & size,
              ));
            });

            // Draw touched surfaces on top, with first touched on top
            childViews.addAll(touchedSurfaceWidgets);

            return new Stack(children: childViews);
          }));
}
