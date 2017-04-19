// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'child_view_node.dart';
import 'story_relationships.dart';
import 'surface_widget.dart';

const Duration _kAnimationDuration = const Duration(milliseconds: 500);

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

  void _setOffset(double offset) {
    setState(() {
      this.offset = offset;
      // HACK(alangardner): No better time to ensure removed items are released
      // Prevents dismissed views from reappearing
      nodeToBeRemoved = null;
    });
  }

  void _endOffset(double velocity) {
    _log('Offset finished w/ velocity: $velocity');
    setState(() {
      // HACK(alangardner): Harcoded distances for swipe gesture
      // to avoid complicated layout work for this throwaway version.
      if (offset > 200.0) {
        nodeToBeRemoved = children.removeLast();
      } else if (offset < 200.0) {
        children.last.relationship = kSerial;
      }
      this.offset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final double totalWidth = constraints.maxWidth;
      final double leftWidth = totalWidth / 3.0;
      final double rightWidth = totalWidth - leftWidth;
      final Duration animationDuration =
          offset == 0.0 ? _kAnimationDuration : const Duration(milliseconds: 1);
      final List<Widget> childViews = <Widget>[];
      if (children.isEmpty) {
        // Add no children
      } else {
        if (children.length == 1) {
          ChildViewNode soleView = children.first;
          childViews.add(new AnimatedPositioned(
              key: new ObjectKey(soleView),
              top: 0.0,
              bottom: 0.0,
              left: offset,
              width: totalWidth,
              curve: Curves.fastOutSlowIn,
              duration: animationDuration,
              child: new Container(
                  child: new ChildView(connection: soleView.connection))));
        } else if (children.last.relationship == kSerial) {
          // One child is full screen
          ChildViewNode topView = children.last;
          childViews.add(new AnimatedPositioned(
              key: new ObjectKey(topView),
              top: 0.0,
              bottom: 0.0,
              left: offset,
              width: totalWidth,
              curve: Curves.fastOutSlowIn,
              duration: animationDuration,
              child: new SurfaceWidget(
                  topView, this._setOffset, this._endOffset)));
          // Animate off previous
          if (children.length > 1) {
            ChildViewNode previousView = children[children.length - 2];
            if (previousView.relationship == kSerial || children.length == 2) {
              childViews.add(new AnimatedPositioned(
                  key: new ObjectKey(previousView),
                  top: 0.0,
                  bottom: 0.0,
                  left: -totalWidth + offset,
                  width: totalWidth,
                  curve: Curves.fastOutSlowIn,
                  duration: animationDuration,
                  child: new SurfaceWidget(
                      previousView, this._setOffset, this._endOffset)));
            } else if (previousView.relationship == kHierarchical) {
              ChildViewNode previousPreviousView =
                  children[children.length - 3];
              childViews.add(new AnimatedPositioned(
                  key: new ObjectKey(previousPreviousView),
                  top: 0.0,
                  bottom: 0.0,
                  left: -totalWidth + offset,
                  width: leftWidth,
                  curve: Curves.fastOutSlowIn,
                  duration: animationDuration,
                  child: new SurfaceWidget(
                      previousPreviousView, this._setOffset, this._endOffset)));
              childViews.add(new AnimatedPositioned(
                  key: new ObjectKey(previousView),
                  top: 0.0,
                  bottom: 0.0,
                  left: -rightWidth + offset,
                  width: rightWidth,
                  curve: Curves.fastOutSlowIn,
                  duration: animationDuration,
                  child: new SurfaceWidget(
                      previousView, this._setOffset, this._endOffset)));
            }
          }
        }
        if (children.length > 1 &&
            children.last.relationship == kHierarchical) {
          // Two children are 1/3 for previous focus, 2/3 for current focus
          ChildViewNode leftView = children[children.length - 2];
          ChildViewNode rightView = children.last;
          childViews.add(new AnimatedPositioned(
              key: new ObjectKey(leftView),
              top: 0.0,
              bottom: 0.0,
              left: offset,
              width: leftWidth,
              curve: Curves.fastOutSlowIn,
              duration: animationDuration,
              child: new SurfaceWidget(
                  leftView, this._setOffset, this._endOffset)));
          childViews.add(new AnimatedPositioned(
              key: new ObjectKey(rightView),
              top: 0.0,
              bottom: 0.0,
              left: leftWidth + offset,
              width: rightWidth,
              curve: Curves.fastOutSlowIn,
              duration: animationDuration,
              child: new SurfaceWidget(
                  rightView, this._setOffset, this._endOffset)));
          // Animate off previous
          if (children.length > 2) {
            ChildViewNode offscreenLeftView = children[children.length - 3];
            childViews.add(new AnimatedPositioned(
                key: new ObjectKey(offscreenLeftView),
                top: 0.0,
                bottom: 0.0,
                left: -leftWidth + offset,
                width: leftWidth,
                curve: Curves.fastOutSlowIn,
                duration: animationDuration,
                child: new SurfaceWidget(
                    offscreenLeftView, this._setOffset, this._endOffset)));
          }
        }
      }
      if (nodeToBeAppended != null) {
        // Upcoming current views animate in from the right
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(nodeToBeAppended),
            top: 0.0,
            bottom: 0.0,
            left: totalWidth + offset,
            width: nodeToBeAppended.relationship == kSerial || children.isEmpty
                ? totalWidth
                : rightWidth,
            curve: Curves.fastOutSlowIn,
            duration: animationDuration,
            child: new SurfaceWidget(
                nodeToBeAppended, this._setOffset, this._endOffset)));
        scheduleMicrotask(() {
          setState(() {
            children.add(nodeToBeAppended);
            nodeToBeAppended = null;
          });
        });
      }
      if (nodeToBeRemoved != null) {
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(nodeToBeRemoved),
            top: 0.0,
            bottom: 0.0,
            left: totalWidth + offset,
            width: nodeToBeRemoved.relationship == kSerial || children.isEmpty
                ? totalWidth
                : rightWidth,
            curve: Curves.fastOutSlowIn,
            duration: animationDuration,
            child: new SurfaceWidget(
                nodeToBeRemoved, this._setOffset, this._endOffset)));
      }
      return new Stack(children: childViews);
    });
  }
}
