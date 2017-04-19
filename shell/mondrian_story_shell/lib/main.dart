// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.story/story_shell.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:graphlib/graphlib.dart';

const String _kSerial = '';
const String _kHierarchical = 'h';
const String _kDependent = 'd';
const Duration _kAnimationDuration = const Duration(milliseconds: 500);
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
final GlobalKey<SurfaceLayoutState> _surfaceLayoutKey =
    new GlobalKey<SurfaceLayoutState>();

/// This is used for keeping the reference around.
StoryShellFactoryImpl _storyShellFactory;

/// Surface-graph representation
/// Nodes are surfaces, edges are relationships
Graph _surfaceGraph;

/// The currently focused surface
int _focusedSurfaceId;

/// The list of previous focusedSurfaces
List<int> _focusedSurfaces;

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Sets initial offset, used to determine if a surface is being dismissed
typedef void SurfaceHandleOffsetCallback(double offset);

/// Callback for handling surface drag ends,
/// determines if surface is being dismissed
typedef void SurfaceHandleEndCallback(double velocity);

/// Frame for child views
class SurfaceWidget extends StatefulWidget {
  final ChildViewNode _node;
  final SurfaceHandleOffsetCallback _offsetCallback;
  final SurfaceHandleEndCallback _endCallback;

  /// SurfaceWidget
  /// @param _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidget(this._node, this._offsetCallback, this._endCallback, {Key key})
      : super(key: key);

  @override
  SurfaceWidgetState createState() =>
      new SurfaceWidgetState(_node, _offsetCallback, _endCallback);
}

/// Frame for child views
class SurfaceWidgetState extends State<SurfaceWidget> {
  final ChildViewNode _node;

  /// Used for surface dismissal
  final SurfaceHandleOffsetCallback _offsetCallback;

  /// Called when surface drags end to determine surface dismissal
  final SurfaceHandleEndCallback _endCallback;
  double _offset = 0.0;

  /// SurfaceWidgetState
  /// @params _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidgetState(this._node, this._offsetCallback, this._endCallback);

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
        key: new ObjectKey(this),
        onHorizontalDragStart: (DragStartDetails details) {
          _log("Drag started.");
          _offset = 0.0;
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (details.primaryDelta != 0.0) {
            _offset += details.primaryDelta;
            _offsetCallback(_offset);
          }
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          _log("Drag ended.");
          _endCallback(details.primaryVelocity);
        },
        behavior: HitTestBehavior.opaque,
        child: new Container(
          padding: const EdgeInsets.only(right: 20.0, left: 20.0),
          child: new ChildView(connection: _node.connection),
        ));
  }
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  /// SurfaceLayout
  SurfaceLayout({Key key}) : super(key: key);

  @override
  SurfaceLayoutState createState() => new SurfaceLayoutState();
}

/// Class describing a surface node: id, view, parent and surface relationship
class ChildViewNode {
  /// The ID of this child
  final int id;

  /// Connection to underlying view
  final ChildViewConnection connection;

  /// ID of parent
  final int parentId;

  /// Relationship to parent
  String relationship;

  /// ChildViewNode
  /// @params connection The Mozart View
  /// @params id The id of this view
  /// @params parentId The id of the parent surface's view
  /// @params relationship The relationship between this view and the parent
  ChildViewNode(this.connection, this.id, this.parentId, this.relationship);
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
    _log("Removing child view!");
    setState(() {
      // TODO(alangardner): Remove it with timer after 500 ms
      if (nodeToBeAppended?.connection == c) {
        _log("Removing nodeToBeAppended");
        nodeToBeAppended = null;
      } else {
        children.removeWhere((ChildViewNode n) {
          _log("Removing existing ChildViewNode");
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
    _log("Offset finished w/ velocity: $velocity");
    setState(() {
      // HACK(alangardner): Harcoded distances for swipe gesture
      // to avoid complicated layout work for this throwaway version.
      if (offset > 200.0) {
        nodeToBeRemoved = children.removeLast();
      } else if (offset < 200.0) {
        children.last.relationship = _kSerial;
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
        } else if (children.last.relationship == _kSerial) {
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
            if (previousView.relationship == _kSerial || children.length == 2) {
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
            } else if (previousView.relationship == _kHierarchical) {
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
            children.last.relationship == _kHierarchical) {
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
            width: nodeToBeAppended.relationship == _kSerial || children.isEmpty
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
            width: nodeToBeRemoved.relationship == _kSerial || children.isEmpty
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

/// An implementation of the [StoryShell] interface.
class StoryShellImpl extends StoryShell {
  final StoryShellBinding _storyShellBinding = new StoryShellBinding();
  final StoryContextProxy _storyContext = new StoryContextProxy();

  /// StoryShwllImpl
  /// @params contextHandle: The [InterfaceHandle] to [StoryContext]
  StoryShellImpl(InterfaceHandle<StoryContext> contextHandle) {
    _storyContext.ctrl.bind(contextHandle);
    _surfaceGraph = new Graph();
  }

  /// Bind an [InterfaceRequest] for a [StoryShell] interface to this object.
  void bind(InterfaceRequest<StoryShell> request) {
    _storyShellBinding.bind(this, request);
  }

  /// Introduce a new [ViewOwner] to the current Story, with relationship
  /// of viewType between this view and the [ViewOwner] of id parentId
  /// @params view The [ViewOwner]
  /// @params viewId The ID of the view being added
  /// @params parentId The ID of the parent view
  /// @params viewType The relationship between this view and its parent
  @override
  void connectView(InterfaceHandle<ViewOwner> view, int viewId, int parentId,
      String viewType) {
    _surfaceLayoutKey.currentState.addChild(view, viewId, parentId, viewType);
    // TODO(djmurphy) determine when graph is purged
    _surfaceGraph.setNode(viewId.toString(), view);
    _surfaceGraph.setEdge(parentId.toString(), viewId.toString(), viewType);
    _log("Connected new view: surfaceGraph is now:");
    _log(writeDot(_surfaceGraph));
  }

  /// Terminate the StoryShell
  @override
  void terminate(void done()) {
    _log('StoryShellImpl::terminate call');
    done();
  }
}

/// An implemenation of the [StoryShellFactory] interface.
class StoryShellFactoryImpl extends StoryShellFactory {
  final StoryShellFactoryBinding _binding = new StoryShellFactoryBinding();

  /// Implementation of StoryShell service
  // ignore: unused_field
  StoryShellImpl _storyShell;

  /// Bind an [InterfaceRequest] for a [StoryShellFactory] interface to this.
  void bind(InterfaceRequest<StoryShellFactory> request) {
    _binding.bind(this, request);
  }

  @override
  void create(InterfaceHandle<StoryContext> context,
      InterfaceRequest<StoryShell> request) {
    _storyShell = new StoryShellImpl(context)..bind(request);
    // TODO(alangardner): Figure out what to do if a second call is made
  }
}

/// Entry point.
void main() {
  _log('Mondrian started');

  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(new SurfaceLayout(key: _surfaceLayoutKey));

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _appContext.outgoingServices.addServiceForName(
    (InterfaceRequest<StoryShellFactory> request) {
      _log('Received binding request for StoryShellFactory');
      _storyShellFactory = new StoryShellFactoryImpl()..bind(request);
    },
    StoryShellFactory.serviceName,
  );
}
