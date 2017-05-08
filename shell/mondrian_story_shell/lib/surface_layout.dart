// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
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

  /// Candidate view for addition
  ChildViewNode nodeToBeAppended;

  /// Candidate view for removal
  ChildViewNode nodeToBeRemoved;

  /// Layout offset
  double offset = 0.0;

  /// Add a child surface showing view, with ID viewID to the parent with
  /// ID parentID, with surface relatinonship viewType
  void addChild(InterfaceHandle<ViewOwner> view, int viewId, int parentId,
      String viewType) {
    setState(() {
      if (nodeToBeAppended != null) {
        children.add(nodeToBeAppended);
        nodeToBeAppended = null;
      }
      ChildViewNode node = new ChildViewNode(
          new ChildViewConnection(view, onUnavailable: this._removeChildView),
          viewId,
          parentId,
          viewType);
      if (children.isEmpty) {
        children.add(node);
      } else {
        nodeToBeAppended = node;
      }
    });
  }

  void _removeChildView(ChildViewConnection c) {
    _log('Removing child view!');
    setState(() {
      // TODO(alangardner): Remove it with timer after 500 ms
      if (nodeToBeAppended?.connection == c) {
        _log('Removing nodeToBeAppended');
        nodeToBeAppended = null;
      } else {
        children.removeWhere((ChildViewNode n) {
          _log('Removing existing ChildViewNode');
          return n.connection == c;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final double totalWidth = constraints.maxWidth;
      final double leftWidth = totalWidth / 3.0;
      final double rightWidth = totalWidth - leftWidth;
      final double totalHeight = constraints.maxHeight;
      final List<Widget> childViews = <Widget>[];
      int numActiveViews = 0;
      if (children.isEmpty) {
        // Add no children
      } else if (children.length == 1) {
        ChildViewNode soleView = children.first;
        numActiveViews = 1;
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(soleView),
            top: 0.0,
            left: 0.0,
            width: totalWidth,
            height: totalHeight,
            child: new Container(
                child: new ChildView(connection: soleView.connection))));
      } else if (children.last.relationship == kSerial) {
        // One child is full screen
        ChildViewNode topView = children.last;
        numActiveViews = 1;
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(topView),
            top: 0.0,
            left: 0.0,
            width: totalWidth,
            height: totalHeight,
            child: new SurfaceWidget(topView),
            onDragEnd: (SimulatedDragEndDetails details) {
              _endDrag(topView, details);
            }));
      } else if (children.last.relationship == kHierarchical) {
        ChildViewNode leftView = children[children.length - 2];
        ChildViewNode rightView = children.last;
        numActiveViews = 2;
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(leftView),
            top: 0.0,
            left: 0.0,
            width: leftWidth,
            height: totalHeight,
            child: new SurfaceWidget(leftView),
            onDragEnd: (SimulatedDragEndDetails details) {
              _endDrag(leftView, details);
            }));
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(rightView),
            top: 0.0,
            left: leftWidth,
            width: rightWidth,
            height: totalHeight,
            child: new SurfaceWidget(rightView),
            onDragEnd: (SimulatedDragEndDetails details) {
              _endDrag(rightView, details);
            }));
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
              top: 0.0,
              left: 0.0,
              width: totalWidth,
              height: totalHeight,
              child: new SurfaceWidget(backgroundNode, interactable: false),
            ));
      }
      if (nodeToBeAppended != null) {
        // Upcoming current views animate in from the right
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(nodeToBeAppended),
            top: 0.0,
            left: totalWidth,
            width: nodeToBeAppended.relationship == kSerial || children.isEmpty
                ? totalWidth
                : rightWidth,
            height: totalHeight,
            child: new SurfaceWidget(nodeToBeAppended),
            onDragEnd: (SimulatedDragEndDetails details) {
              _endDrag(nodeToBeAppended, details);
            }));
        scheduleMicrotask(() {
          setState(() {
            children.add(nodeToBeAppended);
            nodeToBeAppended = null;
          });
        });
      }
      if (nodeToBeRemoved != null) {
        childViews.add(new SimulatedPositioned(
            key: new ObjectKey(nodeToBeRemoved),
            top: 0.0,
            left: totalWidth,
            width: nodeToBeRemoved.relationship == kSerial || children.isEmpty
                ? totalWidth
                : rightWidth,
            height: totalHeight,
            child: new SurfaceWidget(nodeToBeRemoved),
            onDragEnd: (SimulatedDragEndDetails details) {
              _endDrag(nodeToBeRemoved, details);
            }));
      }
      return new Stack(children: childViews);
    });
  }
}
