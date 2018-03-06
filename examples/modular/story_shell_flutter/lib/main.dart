// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.story.fidl/story_shell.fidl.dart';
import 'package:lib.surface.fidl._container/container.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.ui.views.fidl._view_token/view_token.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'package:flutter/widgets.dart';

// ignore_for_file: public_member_api_docs

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
final GlobalKey<SurfaceLayoutState> _surfaceLayoutKey =
    new GlobalKey<SurfaceLayoutState>();

/// This is used for keeping the reference around.
// ignore: unused_element
StoryShellImpl _storyShellImpl;

void _log(String msg) {
  print('[FlutterStoryShell] $msg');
}

/// Main layout widget for displaying Surfaces.
class SurfaceLayout extends StatefulWidget {
  const SurfaceLayout({Key key}) : super(key: key);

  @override
  SurfaceLayoutState createState() => new SurfaceLayoutState();
}

/// Maintains state for the avaialble views to display.
class SurfaceLayoutState extends State<SurfaceLayout> {
  final List<ChildViewConnection> children = <ChildViewConnection>[];

  void addChild(InterfaceHandle<ViewOwner> viewHandle) {
    setState(() {
      children.add(new ChildViewConnection(viewHandle,
          onUnavailable: (ChildViewConnection c) {
        setState(() {
          children.remove(c);
        });
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> childViews = <Widget>[];
    for (ChildViewConnection conn in children) {
      childViews.add(new Expanded(
          child: new Container(
              margin: const EdgeInsets.all(20.0),
              child: new ChildView(connection: conn))));
    }
    return new Center(child: new Row(children: childViews));
  }
}

/// An implementation of the [StoryShell] interface.
class StoryShellImpl implements StoryShell, Lifecycle {
  final StoryShellBinding _storyShellBinding = new StoryShellBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final StoryContextProxy _storyContext = new StoryContextProxy();

  /// StoryShell
  @override
  void initialize(InterfaceHandle<StoryContext> contextHandle) {
    _storyContext.ctrl.bind(contextHandle);
  }

  /// Bind an [InterfaceRequest] for a [StoryShell] interface to this object.
  void bindStoryShell(InterfaceRequest<StoryShell> request) {
    _storyShellBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  /// StoryShell
  @override
  void connectView(InterfaceHandle<ViewOwner> view, String viewId,
      String parentId, SurfaceRelation surfaceRelation) {
    _surfaceLayoutKey.currentState.addChild(view);
  }

  /// StoryShell
  @override
  void focusView(String viewId, String relativeViewId) {
    // Nothing
  }

  /// StoryShell
  @override
  void defocusView(String viewId, void callback()) {
    callback();
  }

  /// StoryShell
  @override
  void addContainer(
      String containerName,
      String parentId,
      SurfaceRelation relation,
      List<ContainerLayout> layout,
      List<ContainerRelationEntry> relationships,
      List<ContainerView> views) {
    // Nothing
  }

  /// StoryShell
  @override
  void terminate() {
    // TODO(mesch): Really terminate, i.e. exit.
    _log('StoryShellImpl::terminate call');
    _storyShellBinding.close();
    _lifecycleBinding.close();
  }
}

/// Entry point.
void main() {
  _log('Flutter StoryShell started');

  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(new SurfaceLayout(key: _surfaceLayoutKey));

  _storyShellImpl = new StoryShellImpl();

  /// Add [StoryShellImpl]'s services to this application's outgoing
  /// ServiceProvider.
  _appContext.outgoingServices
    ..addServiceForName((InterfaceRequest<StoryShell> request) {
      _log('Received binding request for StoryShell');
      _storyShellImpl.bindStoryShell(request);
    }, StoryShell.serviceName)
    ..addServiceForName((InterfaceRequest<Lifecycle> request) {
      _log('Received binding request for Lifecycle');
      _storyShellImpl.bindLifecycle(request);
    }, Lifecycle.serviceName);
}
