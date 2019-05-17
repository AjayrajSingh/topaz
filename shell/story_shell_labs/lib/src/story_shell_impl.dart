// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
// TODO: figure out how to include layout.dart instead
import 'package:story_shell_labs_lib/layout/deja_layout.dart';
import 'package:meta/meta.dart';

import 'story_visual_state_watcher_impl.dart';

/// An implementation of the [StoryShell] interface for Story Shell Labs.
class StoryShellImpl extends fidl_modular.StoryShell {
  final _storyShellContext = fidl_modular.StoryShellContextProxy();
  final _visualStateWatcherBinding =
      fidl_modular.StoryVisualStateWatcherBinding();
  final DejaLayout layoutManager;

  fidl_modular.StoryShellBinding _storyShellBinding;
  StoryVisualStateWatcherImpl _storyVisualStateWatcher;

  // TODO: add to this stream when a surface focus changes in
  // DejaCompose presenter.
  final _focusEventStreamController = StreamController<String>.broadcast();

  StoryShellImpl({@required this.layoutManager}) {
    Lifecycle().addTerminateListener(_onLifecycleTerminate);
  }

  void bind(fidl.InterfaceRequest<fidl_modular.StoryShell> request) {
    log.info('Received binding request for StoryShell');
    _clearBinding();
    _storyShellBinding = fidl_modular.StoryShellBinding()..bind(this, request);
  }

  @override
  Future<void> initialize(
      fidl.InterfaceHandle<fidl_modular.StoryShellContext>
          contextHandle) async {
    _storyShellContext.ctrl.bind(contextHandle);
    _storyVisualStateWatcher = StoryVisualStateWatcherImpl();
    await _storyShellContext.watchVisualState(
        _visualStateWatcherBinding.wrap(_storyVisualStateWatcher));
    // TODO: we can reload story state from the link. Links are
    // deprecated though. New solution needed.
  }

  /// Add a new surface to the story.
  @override
  Future<void> addSurface(
    fidl_modular.ViewConnection viewConnection,
    fidl_modular.SurfaceInfo surfaceInfo,
  ) async {
    log.info('addSurface ${viewConnection.surfaceId}');
    layoutManager.addSurface(
        // TODO: get the intent and parameters from the addSurface call.
        intent: 'no action yet',
        parameters: UnmodifiableListView<String>([]),
        surfaceId: viewConnection.surfaceId,
        view: ChildViewConnection(viewConnection.viewHolderToken));
  }

  /// DEPRECATED:  For transition purposes only.
  @override
  Future<void> addSurface2(
    fidl_modular.ViewConnection2 viewConnection,
    fidl_modular.SurfaceInfo surfaceInfo,
  ) async {
    return addSurface(
        fidl_modular.ViewConnection(
            surfaceId: viewConnection.surfaceId,
            viewHolderToken: viewConnection.viewHolderToken),
        surfaceInfo);
  }

  /// Focus the surface with this id
  @override
  Future<void> focusSurface(String surfaceId) async {
    log.warning('focusSurface not implemented');
  }

  /// Defocus the surface with this id
  @override
  Future<void> defocusSurface(String surfaceId) async {
    log.warning('defocusSurface not implemented');
  }

  @override
  Future<void> removeSurface(String surfaceId) async {
    log.info('removeSurface $surfaceId');
    layoutManager.removeSurface([surfaceId]);
  }

  @override
  Future<void> reconnectView(fidl_modular.ViewConnection viewConnection) async {
    log.warning('reconnectView not implemented ${viewConnection.surfaceId}');
  }

  @override
  Future<void> updateSurface(
    fidl_modular.ViewConnection viewConnection,
    fidl_modular.SurfaceInfo surfaceInfo,
  ) async {
    log.warning('updateSurface no implemented');
  }

  @override
  Stream<String> get onSurfaceFocused => _focusEventStreamController.stream;

  @Deprecated('Deprecated')
  @override
  Future<void> addContainer(
    String containerName,
    String parentId,
    fidl_modular.SurfaceRelation relation,
    List<fidl_modular.ContainerLayout> layouts,
    List<fidl_modular.ContainerRelationEntry> relationships,
    List<fidl_modular.ContainerView> views,
  ) async {}

  Future<void> _onLifecycleTerminate() async {
    _clearBinding();
    await _focusEventStreamController.close();
  }

  void _clearBinding() {
    if (_storyShellBinding != null && _storyShellBinding.isBound) {
      _storyShellBinding.unbind();
      _storyShellBinding = null;
    }
  }
}
