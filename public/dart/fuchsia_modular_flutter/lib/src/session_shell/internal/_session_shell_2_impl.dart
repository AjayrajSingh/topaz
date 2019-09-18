// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart'
    show Presentation, PresentationProxy;
import 'package:fidl_fuchsia_ui_views/fidl_async.dart' show ViewHolderToken;
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:fuchsia_services/services.dart' show StartupContext;

import '../../session_shell_2.dart';
import '../../story_2.dart';
import '_focus_request_watcher_impl.dart';
import '_focus_watcher_impl.dart';
import '_modular_session_shell_impl.dart';
import '_session_shell_presentation_provider_impl.dart';
import '_story_provider_watcher_impl.dart';
import '_story_watcher_impl.dart';

typedef Story2Factory = Story2 Function({
  SessionShell2 sessionShell,
  modular.StoryInfo2 info,
  modular.StoryController controller,
});
typedef Story2Callback = void Function(Story2);

/// Defines a class that encapsulates FIDL interfaces used to build a 'Session
/// Shell' for Fuchsia.
///
/// A Session Shell's primary responsibility is to display
/// and manage a set of [Story2] instances. As such it provides a Session Shell
/// author a set of callbacks to be notified when a story is started, stopped
/// or changed. It allows stories to be deleted and focused.
///
/// This class is part of a soft-transition of [StoryInfo] from struct to table.
/// Clients should use [SessionShellImpl] once [StoryInfo] is a table. See MF-481.
/// TODO(MF-481) Remove once StoryInfo transitioned to table
class SessionShell2Impl implements SessionShell2 {
  /// The [StartupContext] used to initialize SessionShell.
  final StartupContext startupContext;

  /// Callback when a new [Story] is started. Returns an instance of [Story2].
  final Story2Factory onStoryStarted;

  /// Callback when a [Story] is deleted.
  final Story2Callback onStoryDeleted;

  /// Callback when a [Story] is changed.
  final Story2Callback onStoryChanged;

  /// Holds the [Story2] instance mapped by it's id.
  final _stories = <String, Story2>{};

  /// Holds the [modular.StoryWatcherBinding] instances mapped by story id.
  final _storyWatchers = <String, modular.StoryWatcherBinding>{};

  final _focusController = modular.FocusControllerProxy();
  final _focusProvider = modular.FocusProviderProxy();
  final _focusRequestWatcherBinding = modular.FocusRequestWatcherBinding();
  final _focusWatcherBinding = modular.FocusWatcherBinding();
  final _sessionShellBinding = modular.SessionShellBinding();
  final _storyProviderWatcherBinding = modular.StoryProviderWatcherBinding();
  final _presentationBindings =
      <modular.SessionShellPresentationProviderBinding>[];
  final _visualStateWatchers = <String, modular.StoryVisualStateWatcherProxy>{};

  modular.SessionShellContextProxy _sessionShellContext;
  modular.PuppetMasterProxy _puppetMaster;
  modular.StoryProviderProxy _storyProvider;
  PresentationProxy _presentation;

  /// Constructor.
  SessionShell2Impl({
    @required this.startupContext,
    @required this.onStoryStarted,
    this.onStoryChanged,
    this.onStoryDeleted,
  })  : assert(startupContext != null),
        assert(onStoryStarted != null);

  /// Register this instance of Session Shell with modular framework.
  @override
  void start() {
    ArgumentError.checkNotNull(startupContext, 'startupContext');

    // Watch modular framework for stories and focus.
    watch(storyProvider, context);

    // Advertise [modular.SessionShell] service.
    startupContext.outgoing.addPublicService(
        (InterfaceRequest<modular.SessionShell> request) => _sessionShellBinding
            .bind(ModularSessionShellImpl(_attachView, _detachView), request),
        modular.SessionShell.$serviceName);

    // Advertise [modular.SessionShellPresentationProvider] service.
    startupContext.outgoing.addPublicService(
      (InterfaceRequest<modular.SessionShellPresentationProvider> request) =>
          _presentationBindings.add(
        modular.SessionShellPresentationProviderBinding()
          ..bind(
              SessionShellPresentationProviderImpl(context.getPresentation,
                  (storyId, watcher) {
                _visualStateWatchers[storyId] =
                    modular.StoryVisualStateWatcherProxy()..ctrl.bind(watcher);
                _updateVisualStateWatchers();
              }),
              request),
      ),
      modular.SessionShellPresentationProvider.$serviceName,
    );
  }

  /// Unregister and disconnect from modular framework.
  @override
  void stop() {
    _focusProvider.ctrl.close();
    _focusWatcherBinding.close();
    _focusRequestWatcherBinding.close();
    _focusController.ctrl.close();
    _storyProviderWatcherBinding.close();
    _storyProvider.ctrl.close();
    _sessionShellContext.ctrl.close();
  }

  /// The list of stories in the system.
  @override
  Iterable<Story2> get stories => _stories.values;

  /// The [Story2] that is currently focused. It can be null if no story is
  /// currently in focus.
  @override
  Story2 focusedStory;

  /// Request focus for story with [id].
  @override
  void focusStory(String id) => _onFocusRequest(id);

  /// Delete the story with the id.
  @override
  void deleteStory(String id) {
    puppetMaster.deleteStory(id);
    _onDelete(id);
  }

  /// Stop the story with the id.
  @override
  void stopStory(String id) {
    _onStopRequest(id);
  }

  /// Returns the [SessionShellContext].
  @override
  modular.SessionShellContext get context {
    if (_sessionShellContext == null) {
      _sessionShellContext = modular.SessionShellContextProxy();
      startupContext.incoming.connectToService(_sessionShellContext);
    }
    return _sessionShellContext;
  }

  /// Returns the [Presentation] proxy.
  @override
  Presentation get presentation {
    if (_presentation == null) {
      _presentation = PresentationProxy();
      context.getPresentation(_presentation.ctrl.request());
    }
    return _presentation;
  }

  /// Returns the [StoryProvider] interface from [SessionShellContext].
  @visibleForTesting
  modular.StoryProvider get storyProvider {
    if (_storyProvider == null) {
      _storyProvider = modular.StoryProviderProxy();
      context.getStoryProvider(_storyProvider.ctrl.request());
    }
    return _storyProvider;
  }

  /// Returns the [PuppetMaster] interface from [StartupContext].
  @override
  modular.PuppetMaster get puppetMaster {
    if (_puppetMaster == null) {
      _puppetMaster = modular.PuppetMasterProxy();
      startupContext.incoming.connectToService(_puppetMaster);
    }
    return _puppetMaster;
  }

  /// Watch modular framework for stories and focus.
  @visibleForTesting
  void watch(
    modular.StoryProvider storyProvider,
    modular.SessionShellContext context,
  ) {
    ArgumentError.checkNotNull(storyProvider, 'storyProvider');
    ArgumentError.checkNotNull(context, 'context');

    storyProvider.watch(_storyProviderWatcherBinding
        .wrap(StoryProviderWatcherImpl(_onChange, onChange2, _onDelete)));

    context.getFocusController(_focusController.ctrl.request());
    _focusController.watchRequest(_focusRequestWatcherBinding
        .wrap(FocusRequestWatcherImpl(_onFocusRequest)));

    context.getFocusProvider(_focusProvider.ctrl.request());
    _focusProvider
        .watch(_focusWatcherBinding.wrap(FocusWatcherImpl(onFocusChange)));
  }

  /// Watch modular framework for stories and focus.
  @visibleForTesting
  modular.StoryWatcherBinding watchStory(
      modular.StoryController storyController,
      modular.StoryWatcher storyWatcher) {
    ArgumentError.checkNotNull(storyController, 'storyController');
    ArgumentError.checkNotNull(storyWatcher, 'storyWatcher');

    final watcher = modular.StoryWatcherBinding();
    storyController.watch(watcher.wrap(storyWatcher));
    return watcher;
  }

  /// Called by [modular.StoryProviderWatcher] to update story state.
  /// Unimplemented because this class works only with [StoryInfo2].
  void _onChange(
    modular.StoryInfo info,
    modular.StoryState state,
    modular.StoryVisibilityState visibilityState,
  ) {}

  /// Called by [modular.StoryProviderWatcher] to update story state.
  @visibleForTesting
  void onChange2(
    modular.StoryInfo2 info,
    modular.StoryState state,
    modular.StoryVisibilityState visibilityState,
  ) {
    if (!_stories.containsKey(info.id)) {
      if (state == modular.StoryState.stopped) {
        final storyController = newStoryController();
        storyProvider.getController(info.id, storyController.ctrl.request());
        storyController.requestStart();

        final story = onStoryStarted(
          info: info,
          sessionShell: this,
          controller: storyController,
        )
          ..state = state
          ..visibilityState = visibilityState;

        final watcher = watchStory(storyController,
            StoryWatcherImpl(story.onModuleAdded, story.onModuleFocused));
        _storyWatchers[info.id] = watcher;

        _stories[info.id] = story;

        onStoryChanged?.call(_stories[info.id]);
      }
    } else {
      _stories[info.id]
        ..state = state
        ..visibilityState = visibilityState;

      onStoryChanged?.call(_stories[info.id]);
    }
  }

  /// Returns a new instance of [modular.StoryControllerProxy].
  @visibleForTesting
  modular.StoryControllerProxy newStoryController() =>
      modular.StoryControllerProxy();

  /// Called by [StoryProviderWatcherImpl].
  void _onDelete(String storyId) {
    if (!_stories.containsKey(storyId)) {
      return;
    }

    final story = _stories[storyId];
    _stories.remove(storyId);

    _visualStateWatchers.remove(storyId);

    _storyWatchers.remove(storyId);

    if (focusedStory == story) {
      focusedStory = null;
    }
    onStoryDeleted?.call(story);
  }

  /// Request focus from [modular.FocusController].
  void _onFocusRequest(String storyId) {
    _focusController.set(storyId);
  }

  void _onStopRequest(String storyId) async {
    if (_stories.containsKey(storyId)) {
      final storyController = newStoryController();
      await storyProvider.getController(
          storyId, storyController.ctrl.request());
      await storyController.stop();
    }
  }

  /// Called by [modular.FocusWatcher] to change focus on a story.
  @visibleForTesting
  void onFocusChange(modular.FocusInfo focusInfo) {
    if (focusedStory != null) {
      if (focusInfo.focusedStoryId == focusedStory.id) {
        return;
      }
      focusedStory.focused = false;
      onStoryChanged?.call(focusedStory);
    }

    assert(_stories.containsKey(focusInfo.focusedStoryId));
    focusedStory = _stories[focusInfo.focusedStoryId]..focused = true;
    onStoryChanged?.call(focusedStory);

    _updateVisualStateWatchers();
  }

  /// Called from [ModularSessionShellImpl].
  void _attachView(
      modular.ViewIdentifier viewId, ViewHolderToken viewHolderToken) {
    _stories[viewId.storyId]?.childViewConnection =
        ChildViewConnection(viewHolderToken);
    onStoryChanged?.call(_stories[viewId.storyId]);
  }

  /// Called from [ModularSessionShellImpl].
  void _detachView(modular.ViewIdentifier viewId) {
    _stories[viewId.storyId]?.childViewConnection = null;
    onStoryChanged?.call(_stories[viewId.storyId]);
  }

  void _updateVisualStateWatchers() {
    for (final storyId in _visualStateWatchers.keys) {
      _visualStateWatchers[storyId].onVisualStateChange(
          storyId == focusedStory?.id
              ? modular.StoryVisualState.maximized
              : modular.StoryVisualState.minimized);
    }
  }
}
