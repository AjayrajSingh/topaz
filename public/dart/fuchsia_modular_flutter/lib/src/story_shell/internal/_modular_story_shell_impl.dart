// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:meta/meta.dart';

import 'package:fidl/fidl.dart' show InterfaceRequest, InterfaceHandle;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';

import '../../story_shell.dart';
import '../../surface.dart';

/// Defines an implementation of [modular.StoryShell].
///
/// This class overrides the FIDL methods of [modular.StoryShell] and forwards
/// them to instance of [StoryShell] provided in its constructor.
class ModularStoryShellImpl extends modular.StoryShell {
  final _binding = modular.StoryShellBinding();
  final _storyShellContext = modular.StoryShellContextProxy();
  final _focusEventStreamController = StreamController<String>.broadcast();
  final _surfacesById = <String, Surface>{};

  /// The [StoryShell] that receives calls from this modular story shell impl.
  final StoryShell storyShell;

  /// Constructor.
  ModularStoryShellImpl(this.storyShell) {
    Lifecycle().addTerminateListener(_onTerminate);
  }

  /// Binds this instance to receive messages from the FIDL channel.
  void bind(InterfaceRequest<modular.StoryShell> request) {
    if (request != null) {
      _binding.bind(this, request);
    }
  }

  @override
  Future<void> initialize(
      InterfaceHandle<modular.StoryShellContext> context) async {
    _storyShellContext.ctrl.bind(context);
  }

  @override
  Future<void> addSurface(modular.ViewConnection viewConnection,
      modular.SurfaceInfo surfaceInfo) async {
    // Deprecated. Transitioning to addSurface3 (which will later be renamed
    // addSurface, replacing this method with updated parameter list/types)
    final view = newChildViewConnection(viewConnection);
    final surface = Surface(
      id: viewConnection.surfaceId,
      info: surfaceInfo,
      childViewConnection: view,
    );
    _surfacesById[viewConnection.surfaceId] = surface;
    storyShell.onSurfaceAdded(surface);
  }

  @override
  Future<void> addSurface2(modular.ViewConnection2 viewConnection,
      modular.SurfaceInfo surfaceInfo) async {
    return addSurface(
        modular.ViewConnection(
            surfaceId: viewConnection.surfaceId,
            viewHolderToken: viewConnection.viewHolderToken),
        surfaceInfo);
  }

  @override
  Future<void> addSurface3(modular.ViewConnection viewConnection,
      modular.SurfaceInfo2 surfaceInfo2) async {
    final view = newChildViewConnection(viewConnection);
    final surfaceInfo = modular.SurfaceInfo(
      parentId: surfaceInfo2.parentId,
      surfaceRelation: surfaceInfo2.surfaceRelation,
      moduleManifest: surfaceInfo2.moduleManifest,
      moduleSource: surfaceInfo2.moduleSource,
    );
    final surface = Surface(
      id: viewConnection.surfaceId,
      info: surfaceInfo,
      childViewConnection: view,
    );
    _surfacesById[viewConnection.surfaceId] = surface;
    storyShell.onSurfaceAdded(surface);
  }

  @override
  Future<void> addContainer(
      String containerName,
      String parentId,
      modular.SurfaceRelation relation,
      List<modular.ContainerLayout> layout,
      List<modular.ContainerRelationEntry> relationships,
      List<modular.ContainerView> views) async {}

  @override
  Future<void> removeSurface(String surfaceId) async {
    final surface = _surfacesById[surfaceId];
    storyShell.onSurfaceRemoved(surface);
  }

  @override
  Future<void> focusSurface(String surfaceId) async {
    final surface = _surfacesById[surfaceId];
    storyShell.onSurfaceFocusChange(surface, focus: true);
  }

  @override
  Future<void> defocusSurface(String surfaceId) async {
    final surface = _surfacesById[surfaceId];
    storyShell.onSurfaceFocusChange(surface, focus: false);
  }

  @override
  Stream<String> get onSurfaceFocused => _focusEventStreamController.stream;

  @override
  Future<void> reconnectView(modular.ViewConnection viewConnection) async {}

  @override
  Future<void> updateSurface(modular.ViewConnection viewConnection,
      modular.SurfaceInfo surfaceInfo) async {}

  /// Returns a new instance of [ChildViewConnection]. Used for testing.
  @visibleForTesting
  ChildViewConnection newChildViewConnection(
      modular.ViewConnection viewConnection) {
    return ChildViewConnection(viewConnection.viewHolderToken);
  }

  Future<void> _onTerminate() async {
    if (_binding.isBound) {
      _binding.unbind();
    }
    _storyShellContext.ctrl.close();
    await _focusEventStreamController.close();
  }
}
