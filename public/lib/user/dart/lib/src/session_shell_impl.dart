// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.story.dart/story.dart';

/// Called when [SessionShell.initialize] occurs.
typedef OnSessionShellReady = void Function(
  SessionShellContext sessionShellContext,
  FocusProvider focusProvider,
  FocusController focusController,
  VisibleStoriesController visibleStoriesController,
  StoryProvider storyProvider,
  SuggestionProvider suggestionProvider,
  ContextReader contextReader,
  ContextWriter contextWriter,
  IntelligenceServices intelligenceServices,
  Link link,
);

/// Called at the beginning of [Lifecycle.terminate].
typedef OnSessionShellStopping = void Function();

/// Called at the conclusion of [Lifecycle.terminate].
typedef OnSessionShellStop = void Function();

/// Implements a SessionShell for receiving the services a [SessionShell] needs to
/// operate.
class SessionShellImpl implements Lifecycle {
  /// Binding for the actual SessionShell interface object.
  final SessionShellContextProxy _sessionShellContextProxy =
      new SessionShellContextProxy();
  final FocusProviderProxy _focusProviderProxy = new FocusProviderProxy();
  final FocusControllerProxy _focusControllerProxy = new FocusControllerProxy();
  final VisibleStoriesControllerProxy _visibleStoriesControllerProxy =
      new VisibleStoriesControllerProxy();
  final StoryProviderProxy _storyProviderProxy = new StoryProviderProxy();
  final SuggestionProviderProxy _suggestionProviderProxy =
      new SuggestionProviderProxy();
  final ContextReaderProxy _contextReaderProxy = new ContextReaderProxy();
  final ContextWriterProxy _contextWriterProxy = new ContextWriterProxy();
  final IntelligenceServicesProxy _intelligenceServicesProxy =
      new IntelligenceServicesProxy();
  final LinkProxy _linkProxy = new LinkProxy();

  /// Called when [initialize] occurs.
  final OnSessionShellReady onReady;

  /// Called at the beginning of [Lifecycle.terminate].
  final OnSessionShellStop onStopping;

  /// Called at the conclusion of [Lifecycle.terminate].
  final OnSessionShellStop onStop;

  /// Called when [LinkWatcher.notify] is called.
  final LinkWatcherNotifyCallback onNotify;

  /// Indicates whether the [LinkWatcher] should watch for all changes including
  /// the changes made by this [SessionShell]. If `true`, it calls [Link.watchAll]
  /// to register the [LinkWatcher], and [Link.watch] otherwise. Only takes
  /// effect when the [onNotify] callback is also provided. Defaults to `false`.
  final bool watchAll;

  LinkWatcherBinding _linkWatcherBinding;
  LinkWatcherImpl _linkWatcherImpl;

  /// Constructor.
  SessionShellImpl({
    startupContext,
    this.onReady,
    this.onStopping,
    this.onStop,
    this.onNotify,
    bool watchAll,
  }) : watchAll = watchAll ?? false {
    connectToService(
        startupContext.environmentServices, _sessionShellContextProxy.ctrl);
    _initialize();
  }

  void _initialize() {
    if (onReady != null) {
      _sessionShellContextProxy
        ..getStoryProvider(
          _storyProviderProxy.ctrl.request(),
        )
        ..getSuggestionProvider(
          _suggestionProviderProxy.ctrl.request(),
        )
        ..getVisibleStoriesController(
          _visibleStoriesControllerProxy.ctrl.request(),
        )
        ..getFocusController(
          _focusControllerProxy.ctrl.request(),
        )
        ..getFocusProvider(
          _focusProviderProxy.ctrl.request(),
        )
        ..getIntelligenceServices(
          _intelligenceServicesProxy.ctrl.request(),
        )
        ..getLink(_linkProxy.ctrl.request());
      _intelligenceServicesProxy
        ..getContextReader(_contextReaderProxy.ctrl.request())
        ..getContextWriter(_contextWriterProxy.ctrl.request());

      onReady(
        _sessionShellContextProxy,
        _focusProviderProxy,
        _focusControllerProxy,
        _visibleStoriesControllerProxy,
        _storyProviderProxy,
        _suggestionProviderProxy,
        _contextReaderProxy,
        _contextWriterProxy,
        _intelligenceServicesProxy,
        _linkProxy,
      );
    }

    if (onNotify != null) {
      _linkWatcherImpl = new LinkWatcherImpl(onNotify: onNotify);
      _linkWatcherBinding = new LinkWatcherBinding();

      if (watchAll) {
        _linkProxy.watchAll(_linkWatcherBinding.wrap(_linkWatcherImpl));
      } else {
        _linkProxy.watch(_linkWatcherBinding.wrap(_linkWatcherImpl));
      }
    }
  }

  @override
  void terminate() {
    onStopping?.call();
    _linkWatcherBinding?.close();
    _linkProxy.ctrl.close();
    _sessionShellContextProxy.ctrl.close();
    _storyProviderProxy.ctrl.close();
    _suggestionProviderProxy.ctrl.close();
    _visibleStoriesControllerProxy.ctrl.close();
    _focusControllerProxy.ctrl.close();
    _focusProviderProxy.ctrl.close();
    _contextReaderProxy.ctrl.close();
    _contextWriterProxy.ctrl.close();
    _intelligenceServicesProxy.ctrl.close();
    onStop?.call();
  }
}
