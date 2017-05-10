// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'child_view_node.dart';
import 'simulated_positioned.dart';
import 'story_relationships.dart';
import 'surface_widget.dart';

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  /// SurfaceLayout
  SurfaceLayout({Key key}) : super(key: key);

  @override
  SurfaceLayoutState createState() => new SurfaceLayoutState();
}

/// Maintains state for the avaialble views to display.
class SurfaceLayoutState extends State<SurfaceLayout> {
  /// The list of all child views
  final List<ChildViewNode> children = <ChildViewNode>[];

  /// Candidate view for removal
  ChildViewNode nodeToBeRemoved;

  /// Layout offset
  double offset = 0.0;

  /// Add a child surface showing view, with ID viewID to the parent with
  /// ID parentID, with surface relatinonship viewType
  void addChild(InterfaceHandle<ViewOwner> view, int viewId, int parentId,
      String viewType) {
    setState(() {
      children.add(new ChildViewNode(
          new ChildViewConnection(view, onUnavailable: this._removeChildView),
          viewId,
          parentId,
          viewType));
    });
  }

  void _removeChildView(ChildViewConnection c) {
    _log('Removing child view!');
    setState(() {
      // TODO(alangardner): Remove it with timer after 500 ms
      children.removeWhere((ChildViewNode n) {
        _log('Removing existing ChildViewNode');
        return n.connection == c;
      });
    });
  }

  void _endDrag(ChildViewNode node, SimulatedDragEndDetails details) {
    // HACK(alangardner): Harcoded distances for swipe gesture
    // to avoid complicated layout work for this throwaway version.
    Offset expectedOffset =
        details.offset + (details.velocity.pixelsPerSecond / 5.0);
    // Only remove if greater than threshold ant not root surface.
    if (expectedOffset.distance > 200.0 && children.indexOf(node) != 0) {
      setState(() {
        children.remove(node);
        nodeToBeRemoved = node;
      });
    }
  }

  Widget _surface({ChildViewNode node, Rect rect, Rect initRect}) =>
      new SimulatedPositioned(
        key: new ObjectKey(node),
        rect: rect,
        initRect: initRect,
        child: new SurfaceWidget(node),
        onDragEnd: (SimulatedDragEndDetails details) {
          _endDrag(node, details);
        },
      );

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final Offset topLeft = Offset.zero;
      final Offset offscreen = constraints.biggest.topRight(Offset.zero);
      final Rect full = topLeft & constraints.biggest;
      final Rect left = topLeft & new Size(full.width / 3.0, full.height);
      final Rect right = (topLeft + left.topRight) &
          new Size(full.width - left.width, full.height);
      final List<Widget> childViews = <Widget>[];
      int numActiveViews = 0;
      if (children.isEmpty) {
        // Add no children
      } else if (children.length == 1) {
        ChildViewNode soleView = children.first;
        numActiveViews = 1;
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(soleView),
            rect: full,
            initRect: full.shift(offscreen),
            child: new Container(
                child: new ChildView(connection: soleView.connection))));
      } else if (children.last.relationship == kSerial) {
        numActiveViews = 1;
        childViews.add(_surface(
          node: children.last,
          rect: full,
          initRect: full.shift(offscreen),
        ));
      } else if (children.last.relationship == kHierarchical) {
        numActiveViews = 2;
        childViews.add(_surface(
          node: children[children.length - 2],
          rect: left,
          initRect: left.shift(offscreen),
        ));
        childViews.add(_surface(
          node: children.last,
          rect: right,
          initRect: right.shift(offscreen),
        ));
      }
      List<ChildViewNode> backgroundNodes = children.sublist(
          max(0, children.length - numActiveViews - 2),
          max(0, children.length - numActiveViews));
      for (ChildViewNode backgroundNode in backgroundNodes.reversed) {
        _log('Background node: $backgroundNode');
        // Reversed because we insert backward
        childViews.insert(
          0,
          new SimulatedPositioned(
            key: new ObjectKey(backgroundNode),
            rect: full,
            child: new SurfaceWidget(backgroundNode, interactable: false),
          ),
        );
      }
      // Outgoing views animate to/from the right
      if (nodeToBeRemoved != null) {
        Rect offscreenRect = offscreen &
            (nodeToBeRemoved.relationship == kSerial || children.isEmpty
                ? full.size
                : right.size);
        childViews.add(_surface(
          node: nodeToBeRemoved,
          rect: offscreenRect,
        ));
      }
      return new Stack(children: childViews);
    });
  }
}
