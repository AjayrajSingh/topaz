// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/fuchsia.dart' as fuchsia;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.app.dart/app.dart';

/// Called when [UserShell.initialize] occurs.
typedef OnDankUserShellReady = void Function(UserShellContext userShellContext);

/// This is a lightweight class that acquires a [UserShellContextProxy]
/// and passes it to the [onReady] callback. It also implements other
/// lifecycle and focus watcher functionality.
class DankUserShellImpl
    implements
        UserShellPresentationProvider,
        FocusWatcher,
        Lifecycle {
  /// Constructor.
  DankUserShellImpl({startupContext, this.onReady}) {
    connectToService(startupContext.environmentServices, _userShellContextProxy.ctrl);
    _initialize();
  }

  /// Binding for the actual UserShell interface object.
  final _userShellContextProxy = UserShellContextProxy();

  /// Binding for the [FocusProvider] proxy.
  final _focusProviderProxy = FocusProviderProxy();

  /// Mapping of story id to [StoryVisualStateWatcher] handle.
  final _visualStateWatchers = <String, StoryVisualStateWatcherProxy>{};

  /// Binding for [FocusWatcher] implemented by this UserShell.
  final _focusWatcherBinding = FocusWatcherBinding();

  /// Called when [initialize] occurs.
  final OnDankUserShellReady onReady;

  String _lastFocusedStoryId;

  void _initialize() {
    if (onReady != null) {
      _userShellContextProxy
          .getFocusProvider(_focusProviderProxy.ctrl.request());
      _focusProviderProxy.watch(_focusWatcherBinding.wrap(this));

      onReady(_userShellContextProxy);
    }
  }

  @override
  void terminate() => fuchsia.exit(0);

  @override
  void getPresentation(
    String storyId,
    InterfaceRequest<Presentation> request,
  ) =>
      _userShellContextProxy.getPresentation(request);

  @override
  void watchVisualState(
    String storyId,
    InterfaceHandle<StoryVisualStateWatcher> watcherHandle,
  ) {
    void removeWatcher() => _visualStateWatchers.remove(storyId);

    final watcherProxy = StoryVisualStateWatcherProxy();

    watcherProxy.ctrl
      ..bind(watcherHandle)
      ..onClose = removeWatcher
      ..onConnectionError = removeWatcher;

    _visualStateWatchers[storyId] = watcherProxy;

    _notifyWatchers();
  }

  @override
  void onFocusChange(FocusInfo focusInfo) {
    _lastFocusedStoryId = focusInfo.focusedStoryId;

    _notifyWatchers();
  }

  void _notifyWatchers() {
    for (final entry in _visualStateWatchers.entries) {
      entry.value.onVisualStateChange(
        entry.key == _lastFocusedStoryId
            ? StoryVisualState.maximized
            : StoryVisualState.minimized,
      );
    }
  }
}
