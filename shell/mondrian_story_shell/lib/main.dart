// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.story/story_shell.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'model.dart';
import 'surface_layout.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
StoryShellFactoryImpl _storyShellFactory;

SurfaceGraph _surfaceGraph;

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// An implementation of the [StoryShell] interface.
class StoryShellImpl extends StoryShell {
  final StoryShellBinding _storyShellBinding = new StoryShellBinding();
  final StoryContextProxy _storyContext = new StoryContextProxy();

  /// StoryShellImpl
  /// @params contextHandle: The [InterfaceHandle] to [StoryContext]
  StoryShellImpl(InterfaceHandle<StoryContext> contextHandle) {
    _storyContext.ctrl.bind(contextHandle);
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
    _log('Connecting view $viewId with parent $parentId');
    _surfaceGraph.addSurface(viewId.toString(), parentId.toString(), viewType);

    // Separated calls in prep for asynchronous availability of view
    _surfaceGraph.connectView(viewId.toString(), view);
    _surfaceGraph.focusSurface(viewId.toString());
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

  _surfaceGraph = new SurfaceGraph();
  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(new WindowMediaQuery(
      child: new ScopedModel<SurfaceGraph>(
          model: _surfaceGraph, child: new SurfaceLayout())));

  _appContext.outgoingServices.addServiceForName(
    (InterfaceRequest<StoryShellFactory> request) {
      _log('Received binding request for StoryShellFactory');
      _storyShellFactory = new StoryShellFactoryImpl()..bind(request);
    },
    StoryShellFactory.serviceName,
  );
}
