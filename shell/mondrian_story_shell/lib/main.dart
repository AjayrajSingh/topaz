// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.story/story_shell.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'logo.dart';
import 'model.dart';
import 'overview.dart';
import 'surface_details.dart';
import 'surface_director.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

/// This is used for keeping the reference around.
StoryShellFactoryImpl _storyShellFactory;

SurfaceGraph _surfaceGraph;

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
  void connectView(InterfaceHandle<ViewOwner> view, String viewId,
      String parentId, SurfaceRelation surfaceRelation) {
    log.fine('Connecting view $viewId with parent $parentId');
    _surfaceGraph.addSurface(
      viewId,
      new SurfaceProperties(),
      parentId,
      surfaceRelation ?? new SurfaceRelation(),
    );

    // Separated calls in prep for asynchronous availability of view
    _surfaceGraph.connectView(viewId, view);
  }

  /// Focus the view with this id
  @override
  void focusView(String viewId, String relativeViewId) {
    _surfaceGraph.focusSurface(viewId, relativeViewId);
  }

  /// Defocus the view with this id
  @override
  void defocusView(String viewId, void callback()) {
    _surfaceGraph.dismissSurface(viewId);
    // TODO(alangardner, djmurphy): Make Mondrian not crash if the process
    // associated with viewId is closed after callback returns.
    callback();
  }

  /// Terminate the StoryShell
  @override
  void terminate(void done()) {
    log.info('StoryShellImpl::terminate call');
    _storyContext.ctrl.close();
    done();
    _storyShellBinding.close();
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

/// High level class for choosing between presentations
class Mondrian extends StatefulWidget {
  /// Constructor
  Mondrian({Key key}) : super(key: key);

  @override
  MondrianState createState() => new MondrianState();
}

/// State
class MondrianState extends State<Mondrian> {
  bool _showOverview = false;

  @override
  Widget build(BuildContext context) => new Stack(
        children: <Widget>[
          new ScopedModel<SurfaceGraph>(
            model: _surfaceGraph,
            child: _showOverview ? new Overview() : new SurfaceDirector(),
          ),
          new Positioned(
            left: 0.0,
            bottom: 0.0,
            child: new GestureDetector(
              child: new Container(
                width: 40.0,
                height: 40.0,
                child: _showOverview ? new MondrianLogo() : null,
              ),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showOverview = !_showOverview;
                });
              },
            ),
          ),
        ],
      );
}

/// Entry point.
void main() {
  setupLogger(name: 'Mondrian');
  log.info('Started');

  _surfaceGraph = new SurfaceGraph();
  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(new WindowMediaQuery(child: new Mondrian()));

  _appContext.outgoingServices.addServiceForName(
    (InterfaceRequest<StoryShellFactory> request) {
      log.fine('Received binding request for StoryShellFactory');
      _storyShellFactory = new StoryShellFactoryImpl()..bind(request);
    },
    StoryShellFactory.serviceName,
  );
}
