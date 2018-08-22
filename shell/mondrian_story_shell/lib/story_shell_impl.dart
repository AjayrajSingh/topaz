// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:fuchsia/fuchsia.dart' show exit;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.story_shell/common.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/utils.dart';

import 'models/surface/surface_graph.dart';
import 'models/surface/surface_properties.dart';


/// An implementation of the [StoryShell] interface.
class StoryShellImpl implements StoryShell, StoryVisualStateWatcher, Lifecycle {
  final StoryShellBinding _storyShellBinding = new StoryShellBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final StoryShellContextProxy _storyShellContext =
      new StoryShellContextProxy();
  final PointerEventsListener _pointerEventsListener =
      new PointerEventsListener();
  final KeyListener keyListener;
  final StoryVisualStateWatcherBinding _visualStateWatcherBinding =
      new StoryVisualStateWatcherBinding();
  final SurfaceGraph surfaceGraph;
  StoryVisualState _visualState;

  StoryShellImpl({this.surfaceGraph, this.keyListener});

  /// StoryShell
  @override
  void initialize(InterfaceHandle<StoryShellContext> contextHandle) {
    _storyShellContext.ctrl.bind(contextHandle);
    _storyShellContext.watchVisualState(_visualStateWatcherBinding.wrap(this));
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
  void addView(
    InterfaceHandle<ViewOwner> view,
    String viewId,
    String parentId,
    SurfaceRelation surfaceRelation,
    ModuleManifest manifest,
    ModuleSource source, // TODO(djmurphy): use this.
  ) {
    trace('connecting view $viewId with parent $parentId');
    log.fine('Connecting view $viewId with parent $parentId');
    surfaceGraph
      ..addSurface(
        viewId,
        new SurfaceProperties(),
        parentId,
        surfaceRelation ?? const SurfaceRelation(),
        manifest != null ? manifest.compositionPattern : '',
      )
      ..connectView(viewId, view);
  }

  /// Focus the view with this id
  @override
  void focusView(String viewId, String relativeViewId) {
    trace('focusing view $viewId');
    surfaceGraph.focusSurface(viewId, relativeViewId);
  }

  /// Defocus the view with this id
  @override
  void defocusView(String viewId, void callback()) {
    trace('defocusing view $viewId');
    surfaceGraph.dismissSurface(viewId);
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
    surfaceGraph.addContainer(
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
          surfaceGraph.addSurface(
              nodeId, prop, parentId, nodeMap[nodeId].relationship, null);
          addedParents.add(nodeId);
          surfaceGraph.connectView(nodeId, viewMap[nodeId]);
          nodeQueue.remove(nodeId);
          surfaceGraph.focusSurface(nodeId, null);
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
  void terminate() => exit(0);

  @override
  void onVisualStateChange(StoryVisualState visualState) {
    if (_visualState == visualState) {
      return;
    }
    _visualState = visualState;

    _pointerEventsListener.stop();
    if (visualState == StoryVisualState.maximized) {
      PresentationProxy presentationProxy = new PresentationProxy();
      _storyShellContext.getPresentation(presentationProxy.ctrl.request());
      _pointerEventsListener.listen(presentationProxy);
      keyListener?.listen(presentationProxy);
      presentationProxy.ctrl.close();
    }
  }
}
