// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart' show InterfaceRequest, InterfaceHandle;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart' show Presentation;

/// Extends [modular.SessionShellPresentationProvider]. This class forwards the
/// request to get the session shell's presentation and watch a story's visual
/// state.
class SessionShellPresentationProviderImpl
    extends modular.SessionShellPresentationProvider {
  final void Function(InterfaceRequest<Presentation>) _presentationCallback;
  final void Function(String, InterfaceHandle<modular.StoryVisualStateWatcher>)
      _watchVisualStateCallback;

  /// Constructor.
  SessionShellPresentationProviderImpl(
      this._presentationCallback, this._watchVisualStateCallback);

  @override
  Future<void> getPresentation(
    String storyId,
    InterfaceRequest<Presentation> request,
  ) async {
    _presentationCallback(request);
  }

  @override
  Future<void> watchVisualState(
    String storyId,
    InterfaceHandle<modular.StoryVisualStateWatcher> watcherHandle,
  ) async {
    _watchVisualStateCallback(storyId, watcherHandle);
  }
}
