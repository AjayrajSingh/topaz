// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:fidl/fidl.dart' show InterfaceRequest, InterfaceHandle;
import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show
        SessionShellPresentationProvider,
        SessionShellPresentationProviderBinding,
        FocusWatcher,
        StoryVisualStateWatcherProxy,
        FocusWatcherBinding,
        FocusProviderProxy,
        StoryVisualStateWatcher,
        StoryVisualState,
        FocusInfo,
        SessionShellContext;
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart' show Presentation;
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_services/services.dart';

/// Manages which Stories have focus and thus can receive input events from the
/// presenter.
class SessionShellServices {
  /// The session shell
  final SessionShellContext sessionShellContext;

  /// The binding for the [SessionShellPresentationProvider] service implemented
  /// by [SessionShellImpl].
  final _bindings = <SessionShellPresentationProviderBinding>[];

  /// Binding for the [FocusProvider] proxy.
  final _focusProviderProxy = FocusProviderProxy();

  /// Mapping of story id to [StoryVisualStateWatcher] handle.
  final _visualStateWatchers = <String, StoryVisualStateWatcherProxy>{};

  /// Binding for [FocusWatcher] implemented by this SessionShell.
  final _focusWatcherBinding = FocusWatcherBinding();

  String _lastFocusedStoryId;

  // Holds the [Lifecycle] reference to expose the service.
  Lifecycle _lifecycle;

  /// Constructor.
  SessionShellServices({this.sessionShellContext});

  /// Advertises the session shell as a [Lifecycle] and
  /// [SessionShellPresentationProvider] to the rest of the system via
  /// the [StartupContext].
  void advertise() {
    sessionShellContext.getFocusProvider(_focusProviderProxy.ctrl.request());
    _focusProviderProxy
        .watch(_focusWatcherBinding.wrap(_FocusWatcherImpl(this)));

    _lifecycle ??= Lifecycle();

    StartupContext.fromStartupInfo().outgoing.addPublicService(
          (InterfaceRequest<SessionShellPresentationProvider> request) =>
              _bindings.add(
                SessionShellPresentationProviderBinding()
                  ..bind(_SessionShellPresentationProviderImpl(this), request),
              ),
          SessionShellPresentationProvider.$serviceName,
        );
  }

  void _removeWatcher(String storyId) => _visualStateWatchers.remove(storyId);
  void _setWatcher(String storyId, StoryVisualStateWatcherProxy watcher) =>
      _visualStateWatchers[storyId] = watcher;
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

class _SessionShellPresentationProviderImpl
    extends SessionShellPresentationProvider {
  final SessionShellServices _sessionShellServices;
  _SessionShellPresentationProviderImpl(this._sessionShellServices);
  @override
  Future<void> getPresentation(
    String storyId,
    InterfaceRequest<Presentation> request,
  ) =>
      _sessionShellServices.sessionShellContext.getPresentation(request);
  @override
  Future<void> watchVisualState(
    String storyId,
    InterfaceHandle<StoryVisualStateWatcher> watcherHandle,
  ) async {
    final watcherProxy = StoryVisualStateWatcherProxy();
    try {
      watcherProxy.ctrl.bind(watcherHandle);
    } on Exception {
      _sessionShellServices._removeWatcher(storyId);
    }
    _sessionShellServices
      .._setWatcher(storyId, watcherProxy)
      .._notifyWatchers();
  }
}

class _FocusWatcherImpl extends FocusWatcher {
  final SessionShellServices _sessionShellServices;
  _FocusWatcherImpl(this._sessionShellServices);
  @override
  Future<void> onFocusChange(FocusInfo focusInfo) async {
    _sessionShellServices
      .._lastFocusedStoryId = focusInfo.focusedStoryId
      .._notifyWatchers();
  }
}
