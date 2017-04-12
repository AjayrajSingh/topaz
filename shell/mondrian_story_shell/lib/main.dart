// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.story/story_shell.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'package:flutter/widgets.dart';

const Duration _kAnimationDuration = const Duration(milliseconds: 500);
final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
final GlobalKey<SurfaceLayoutState> _surfaceLayoutKey =
    new GlobalKey<SurfaceLayoutState>();

/// This is used for keeping the reference around.
StoryShellFactoryImpl _storyShellFactory;

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Frame for child views
class SurfaceWidget extends StatelessWidget {
  ChildViewNode _childView;

  SurfaceWidget(this._childView) {}

  @override
  Widget build(BuildContext context) {
    return new Container(
      margin: const EdgeInsets.all(5.0),
      child: new ChildView(connection: _childView.connection),
    );
  }
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  SurfaceLayout({Key key}) : super(key: key);

  @override
  SurfaceLayoutState createState() => new SurfaceLayoutState();
}

class ChildViewNode {
  final int id;
  final ChildViewConnection connection;
  final int parentId;
  final String relationship;

  ChildViewNode(this.connection, this.id, this.parentId, this.relationship) {}
}

/// Maintains state for the avaialble views to display.
class SurfaceLayoutState extends State<SurfaceLayout> {
  final List<ChildViewNode> children = <ChildViewNode>[];
  ChildViewNode nodeToBeAppended;

  void addChild(InterfaceHandle<ViewOwner> view, int view_id, int parent_id,
      String view_type) {
    setState(() {
      if (nodeToBeAppended != null) {
        children.add(nodeToBeAppended);
        nodeToBeAppended = null;
      }
      nodeToBeAppended = new ChildViewNode(
          new ChildViewConnection(view, onUnavailable: (ChildViewConnection c) {
            setState(() {
              // TODO(alangardner): Remove it with timer after 500 ms
              if (nodeToBeAppended.connection == c) {
                nodeToBeAppended = null;
              } else {
                children.removeWhere((ChildViewNode v) {
                  v.connection == c;
                });
              }
            });
          }),
          view_id,
          parent_id,
          view_type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final double totalWidth = constraints.maxWidth;
      final double leftWidth = totalWidth / 3.0;
      final double rightWidth = totalWidth - leftWidth;
      final List<Widget> childViews = <Widget>[];
      if (children.isEmpty) {
        // Add no children
      } else if (children.length == 1) {
        // One child is full screen
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(children.first),
            top: 0.0,
            bottom: 0.0,
            left: 0.0,
            width: totalWidth,
            curve: Curves.fastOutSlowIn,
            duration: _kAnimationDuration,
            child: new SurfaceWidget(children.first)));
      } else {
        // Two children are 1/3 for previous focus, 2/3 for current focus
        ChildViewNode leftView = children[children.length - 2];
        ChildViewNode rightView = children.last;
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(leftView),
            top: 0.0,
            bottom: 0.0,
            left: 0.0,
            width: leftWidth,
            curve: Curves.fastOutSlowIn,
            duration: _kAnimationDuration,
            child: new SurfaceWidget(leftView)));
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(rightView),
            top: 0.0,
            bottom: 0.0,
            left: leftWidth,
            width: rightWidth,
            curve: Curves.fastOutSlowIn,
            duration: _kAnimationDuration,
            child: new SurfaceWidget(rightView)));
        if (children.length > 2) {
          // The previous previous view animates out to the left
          ChildViewNode offscreenLeftView = children[children.length - 3];
          childViews.add(new AnimatedPositioned(
              key: new ObjectKey(offscreenLeftView),
              top: 0.0,
              bottom: 0.0,
              left: -leftWidth,
              width: leftWidth,
              curve: Curves.fastOutSlowIn,
              duration: _kAnimationDuration,
              child: new SurfaceWidget(offscreenLeftView)));
        }
      }
      if (nodeToBeAppended != null) {
        // Upcoming current views animate in from the right
        childViews.add(new AnimatedPositioned(
            key: new ObjectKey(nodeToBeAppended),
            top: 0.0,
            bottom: 0.0,
            left: totalWidth,
            width: children.isEmpty ? totalWidth : rightWidth,
            curve: Curves.fastOutSlowIn,
            duration: _kAnimationDuration,
            child: new SurfaceWidget(nodeToBeAppended)));
        scheduleMicrotask(() {
          setState(() {
            children.add(nodeToBeAppended);
            nodeToBeAppended = null;
          });
        });
      }
      return new Stack(children: childViews);
    });
  }
}

/// An implementation of the [StoryShell] interface.
class StoryShellImpl extends StoryShell {
  final StoryShellBinding _storyShellBinding = new StoryShellBinding();
  final StoryContextProxy _storyContext = new StoryContextProxy();

  StoryShellImpl(InterfaceHandle<StoryContext> contextHandle) {
    _storyContext.ctrl.bind(contextHandle);
  }

  /// Bind an [InterfaceRequest] for a [StoryShell] interface to this object.
  void bind(InterfaceRequest<StoryShell> request) {
    _storyShellBinding.bind(this, request);
  }

  /// StoryShell
  @override
  void connectView(InterfaceHandle<ViewOwner> view, int view_id, int parent_id,
      String view_type) {
    _surfaceLayoutKey.currentState
        .addChild(view, view_id, parent_id, view_type);
  }

  /// StoryShell
  @override
  void terminate(void done()) {
    _log('StoryShellImpl::terminate call');
    done();
  }
}

/// An implemenation of the [StoryShellFactory] interface.
class StoryShellFactoryImpl extends StoryShellFactory {
  final StoryShellFactoryBinding _binding = new StoryShellFactoryBinding();
  StoryShellImpl _storyShell;

  /// Bind an [InterfaceRequest] for a [StoryShellFactory] interface to this.
  void bind(InterfaceRequest<StoryShellFactory> request) {
    _binding.bind(this, request);
  }

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
    (request) {
      _log('Received binding request for StoryShellFactory');
      _storyShellFactory = new StoryShellFactoryImpl()..bind(request);
    },
    StoryShellFactory.serviceName,
  );
}
