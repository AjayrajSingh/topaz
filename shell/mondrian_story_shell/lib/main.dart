// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:ui' show window;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia/fuchsia.dart' show exit;
import 'package:lib.app.dart/app.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.story.fidl/story_shell.fidl.dart';
import 'package:lib.surface.fidl._container/container.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.module.fidl._module_data/module_manifest.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.ui.views.fidl._view_token/view_token.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'layout_model.dart';
import 'logo.dart';
import 'model.dart';
import 'overview.dart';
import 'surface_details.dart';
import 'surface_director.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
final DeviceMapWatcherBinding _deviceMapWatcher = new DeviceMapWatcherBinding();

/// This is used for keeping the reference around.
// ignore: unused_element
StoryShellImpl _storyShellImpl;

SurfaceGraph _surfaceGraph;

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

  /// Introduce a new [ViewOwner] to the current Story, with relationship
  /// of viewType between this view and the [ViewOwner] of id parentId
  /// @params view The [ViewOwner]
  /// @params viewId The ID of the view being added
  /// @params parentId The ID of the parent view
  /// @params surfaceRelation The relationship between this view and its parent
  @override
  void connectView(
    InterfaceHandle<ViewOwner> view,
    String viewId,
    String parentId,
    SurfaceRelation surfaceRelation,
    ModuleManifest manifest,
  ) {
    trace('connecting view $viewId with parent $parentId');
    log.fine('Connecting view $viewId with parent $parentId');
    _surfaceGraph
      ..addSurface(
        viewId,
        new SurfaceProperties(),
        parentId,
        surfaceRelation ?? new SurfaceRelation(),
        manifest != null ? manifest.compositionPattern : '',
      )
      ..connectView(viewId, view);
  }

  /// Focus the view with this id
  @override
  void focusView(String viewId, String relativeViewId) {
    trace('focusing view $viewId');
    _surfaceGraph.focusSurface(viewId, relativeViewId);
  }

  /// Defocus the view with this id
  @override
  void defocusView(String viewId, void callback()) {
    trace('defocusing view $viewId');
    _surfaceGraph.dismissSurface(viewId);
    // TODO(alangardner, djmurphy): Make Mondrian not crash if the process
    // associated with viewId is closed after callback returns.
    callback();
  }

  /// Add a container node to the graph, with associated layout as a property,
  /// and optionally specify a parent and a relationship to the parent
  @override
  void addContainer(
      String containerName,
      String parentId,
      SurfaceRelation relation,
      List<ContainerLayout> layouts,
      List<ContainerRelationEntry> relationships,
      List<ContainerView> views) {
    // Add a root node for the container
    trace('adding container $containerName with parent $parentId');
    _surfaceGraph.addContainer(
      containerName,
      new SurfaceProperties(),
      parentId,
      relation,
      layouts,
    );

    Map<String, ContainerRelationEntry> nodeMap =
        <String, ContainerRelationEntry>{};
    Map<String, List<String>> parentChildrenMap = <String, List<String>>{};
    Map<String, InterfaceHandle<ViewOwner>> viewMap =
        <String, InterfaceHandle<ViewOwner>>{};
    for (ContainerView view in views) {
      viewMap[view.nodeName] = view.owner;
    }
    for (ContainerRelationEntry relatedNode in relationships) {
      nodeMap[relatedNode.nodeName] = relatedNode;
      parentChildrenMap
          .putIfAbsent(relatedNode.parentNodeName, () => <String>[])
          .add(relatedNode.nodeName);
    }
    List<String> nodeQueue =
        views.map((ContainerView v) => v.nodeName).toList();
    List<String> addedParents = <String>[containerName];
    int i = 0;
    while (nodeQueue.isNotEmpty) {
      String nodeId = nodeQueue.elementAt(i);
      String parentId = nodeMap[nodeId].parentNodeName;
      if (addedParents.contains(parentId)) {
        for (nodeId in parentChildrenMap[parentId]) {
          SurfaceProperties prop = new SurfaceProperties()
            ..containerMembership = <String>[containerName]
            ..containerLabel = nodeId;
          _surfaceGraph.addSurface(
              nodeId, prop, parentId, nodeMap[nodeId].relationship, null);
          addedParents.add(nodeId);
          _surfaceGraph.connectView(nodeId, viewMap[nodeId]);
          nodeQueue.remove(nodeId);
          _surfaceGraph.focusSurface(nodeId, null);
        }
        i = 0;
      } else {
        i++;
        if (i > nodeQueue.length) {
          log.warning('''Error iterating through container children.
          All nodes iterated without finding all parents specified in
          Container Relations''');
          return;
        }
      }
    }
  }

  /// Terminate the StoryShell.
  @override
  void terminate() {
    trace('terminating');
    log.info('StoryShellImpl::terminate call');
    _storyContext.ctrl.close();
    _storyShellBinding.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

/// High level class for choosing between presentations
class Mondrian extends StatefulWidget {
  /// Constructor
  const Mondrian({Key key}) : super(key: key);

  @override
  MondrianState createState() => new MondrianState();
}

/// State
class MondrianState extends State<Mondrian> {
  bool _showOverview = false;

  @override
  Widget build(BuildContext context) {
    _traceFrame();
    return new Stack(
      children: <Widget>[
        new ScopedModel<SurfaceGraph>(
          model: _surfaceGraph,
          child: _showOverview ? const Overview() : new SurfaceDirector(),
        ),
        new Positioned(
          left: 0.0,
          bottom: 0.0,
          child: new GestureDetector(
            child: new Container(
              width: 40.0,
              height: 40.0,
              child: _showOverview ? const MondrianLogo() : null,
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
}

/// Entry point.
void main() {
  setupLogger(name: 'Mondrian');
  trace('starting');
  log.info('Started');

  LayoutModel layoutModel = new LayoutModel();

  _surfaceGraph = new SurfaceGraph();
  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(
    new Directionality(
      textDirection: TextDirection.ltr,
      child: new WindowMediaQuery(
        child: new ScopedModel<LayoutModel>(
          model: layoutModel,
          child: const Mondrian(),
        ),
      ),
    ),
  );

  DeviceMapProxy deviceMapProxy = new DeviceMapProxy();

  connectToService(_appContext.environmentServices, deviceMapProxy.ctrl);

  deviceMapProxy.watchDeviceMap(
    _deviceMapWatcher.wrap(
      new _DeviceMapWatcherImpl(
        onProfileChanged: layoutModel.onDeviceProfileChanged,
      ),
    ),
  );

  _storyShellImpl = new StoryShellImpl();

  _appContext.outgoingServices
    ..addServiceForName((InterfaceRequest<StoryShell> request) {
      trace('story shell request');
      log.fine('Received binding request for StoryShell');
      _storyShellImpl.bindStoryShell(request);
    }, StoryShell.serviceName)
    ..addServiceForName((InterfaceRequest<Lifecycle> request) {
      trace('lifecycle request');
      log.fine('Received binding request for Lifecycle');
      _storyShellImpl.bindLifecycle(request);
    }, Lifecycle.serviceName);
  trace('started');
}

class _DeviceMapWatcherImpl extends DeviceMapWatcher {
  ValueChanged<Map<String, String>> onProfileChanged;

  _DeviceMapWatcherImpl({this.onProfileChanged});
  @override
  void onDeviceMapChange(DeviceMapEntry entry) {
    trace('device map changed');
    Object decodedJson = json.decode(entry.profile);
    if (decodedJson is Map<String, String>) {
      onProfileChanged(decodedJson);
    } else {
      log.severe(
        'Device profile expected to be a map of strings!'
            ' ${entry.profile}',
      );
    }
  }
}

int _frameCounter = 1;
void _traceFrame() {
  Size size = window.physicalSize / window.devicePixelRatio;
  trace('building, size: $size');
  SchedulerBinding.instance.addPostFrameCallback(_frameCallback);
}

void _frameCallback(Duration duration) {
  Size size = window.physicalSize / window.devicePixelRatio;
  trace('frame $_frameCounter, size: $size');
  _frameCounter++;
  if (size.isEmpty) {
    SchedulerBinding.instance.addPostFrameCallback(_frameCallback);
  }
}
