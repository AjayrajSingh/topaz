// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.context.fidl/context_writer.fidl.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';
import 'package:lib.user.fidl/focus.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.story.dart/story.dart';

/// Called when [UserShell.initialize] occurs.
typedef void OnUserShellReady(
  UserShellContext userShellContext,
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
typedef void OnUserShellStopping();

/// Called at the conclusion of [Lifecycle.terminate].
typedef void OnUserShellStop();

/// Implements a UserShell for receiving the services a [UserShell] needs to
/// operate.
class UserShellImpl implements UserShell, Lifecycle {
  /// Binding for the actual UserShell interface object.
  final UserShellContextProxy _userShellContextProxy =
      new UserShellContextProxy();
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
  final OnUserShellReady onReady;

  /// Called at the beginning of [Lifecycle.terminate].
  final OnUserShellStop onStopping;

  /// Called at the conclusion of [Lifecycle.terminate].
  final OnUserShellStop onStop;

  /// Called when [LinkWatcher.notify] is called.
  final LinkWatcherNotifyCallback onNotify;

  /// Indicates whether the [LinkWatcher] should watch for all changes including
  /// the changes made by this [UserShell]. If `true`, it calls [Link.watchAll]
  /// to register the [LinkWatcher], and [Link.watch] otherwise. Only takes
  /// effect when the [onNotify] callback is also provided. Defaults to `false`.
  final bool watchAll;

  LinkWatcherBinding _linkWatcherBinding;
  LinkWatcherImpl _linkWatcherImpl;

  /// Constructor.
  UserShellImpl({
    this.onReady,
    this.onStopping,
    this.onStop,
    this.onNotify,
    bool watchAll,
  })
      : watchAll = watchAll ?? false;

  @override
  void initialize(
    InterfaceHandle<UserShellContext> userShellContextHandle,
  ) {
    if (onReady != null) {
      _userShellContextProxy.ctrl.bind(userShellContextHandle);
      _userShellContextProxy
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
        _userShellContextProxy,
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
    _userShellContextProxy.ctrl.close();
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
