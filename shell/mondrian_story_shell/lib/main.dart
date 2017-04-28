// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.story/story_shell.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:graphlib/graphlib.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/widgets.dart';

import 'surface_layout.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// Unique identifier for surfaceLayout Widget
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
    // parentId 0 is the 'null' parent case for the first added node
    if (parentId > 0) {
      _surfaceGraph.setEdge(parentId.toString(), viewId.toString(), viewType);
    }
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
  runApp(
    new WindowMediaQuery(child: new SurfaceLayout(key: _surfaceLayoutKey)),
  );

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _appContext.outgoingServices.addServiceForName(
    (InterfaceRequest<StoryShellFactory> request) {
      _log('Received binding request for StoryShellFactory');
      _storyShellFactory = new StoryShellFactoryImpl()..bind(request);
    },
    StoryShellFactory.serviceName,
  );
}
