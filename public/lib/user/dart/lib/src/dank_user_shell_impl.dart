// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/fuchsia.dart' as fuchsia;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:fidl/fidl.dart';

import 'user_shell_impl.dart';

/// Called when [UserShell.initialize] occurs.
typedef OnDankUserShellReady = void Function(
  UserShellContext userShellContext,
);

/// Implements a [UserShell].
/// This is a lightweight version that passes the [UserShellContextProxy]
/// through the [onReady] callback.
class DankUserShellImpl
    implements
        UserShell,
        UserShellPresentationProvider,
        FocusWatcher,
        Lifecycle {
  /// Constructor.
  DankUserShellImpl({
    this.onReady,
    this.onStop,
  });

  /// Binding for the actual UserShell interface object.
  final UserShellContextProxy _userShellContextProxy =
      new UserShellContextProxy();

  /// Binding for the [FocusProvider] proxy.
  final FocusProviderProxy _focusProviderProxy = new FocusProviderProxy();

  /// Mapping of story id to [StoryVisualStateWatcher] handle.
  final Map<String, StoryVisualStateWatcherProxy> _visualStateWatchers =
      <String, StoryVisualStateWatcherProxy>{};

  /// Binding for [FocusWatcher] implemented by this UserShell.
  final FocusWatcherBinding _focusWatcherBinding = new FocusWatcherBinding();

  /// Called when [initialize] occurs.
  final OnDankUserShellReady onReady;

  /// Called at the conclusion of [Lifecycle.terminate].
  final OnUserShellStop onStop;

  @override
  void initialize(
    InterfaceHandle<UserShellContext> userShellContextHandle,
  ) {
    if (onReady != null) {
      _userShellContextProxy.ctrl.bind(userShellContextHandle);
      _userShellContextProxy
          .getFocusProvider(_focusProviderProxy.ctrl.request());
      _focusProviderProxy.watch(_focusWatcherBinding.wrap(this));

      onReady(_userShellContextProxy);
    }
  }

  @override
  void terminate() {
    _focusWatcherBinding.close();
    for (StoryVisualStateWatcherProxy watcher
        in _visualStateWatchers.values.toList()) {
      watcher.ctrl.close();
    }
    _focusProviderProxy.ctrl.close();
    _userShellContextProxy.ctrl.close();
    onStop?.call();
    fuchsia.exit(0);
  }

  @override
  void getPresentation(String storyId, InterfaceRequest<Presentation> request) {
    _userShellContextProxy.getPresentation(request);
  }

  @override
  void watchVisualState(
      String storyId, InterfaceHandle<StoryVisualStateWatcher> watcherHandle) {
    StoryVisualStateWatcherProxy watcherProxy =
        new StoryVisualStateWatcherProxy();
    watcherProxy.ctrl
      ..bind(watcherHandle)
      ..onClose = () => _visualStateWatchers.remove(storyId);
    watcherProxy.ctrl.onConnectionError =
        () => _visualStateWatchers.remove(storyId);

    _visualStateWatchers[storyId] = watcherProxy;
  }

  @override
  void onFocusChange(FocusInfo focusInfo) =>
      _setFocus(focusInfo.focusedStoryId);

  void _setFocus(String storyId) {
    for (MapEntry<String, StoryVisualStateWatcherProxy> entry
        in _visualStateWatchers.entries) {
      entry.value.onVisualStateChange(entry.key == storyId
          ? StoryVisualState.maximized
          : StoryVisualState.minimized);
    }
  }
}
