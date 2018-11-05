// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:home_work_agent/home_work_proposer.dart';
import 'package:lib.widgets/modular.dart';

import 'active_agents_manager.dart';
import 'focus_request_watcher_impl.dart';
import 'initial_focus_setter.dart';
import 'story_provider_story_generator.dart';
import 'suggestion_provider_suggestion_model.dart';
import 'user_logoutter.dart';
import 'wallpaper_chooser.dart';

const String _kLocationTopic = 'location/home_work';

/// Connects [SessionShell]'s services to Armadillo's associated classes.
class ArmadilloSessionShellModel extends SessionShellModel {
  /// Receives the [StoryProvider].
  final StoryProviderStoryGenerator storyProviderStoryGenerator;

  /// Receives the [SuggestionProvider], [FocusController], and
  /// [VisibleStoriesController].
  final SuggestionProviderSuggestionModel suggestionProviderSuggestionModel;

  /// Watches the [FocusController].
  final FocusRequestWatcherImpl focusRequestWatcher;

  /// Receives the [FocusProvider].
  final InitialFocusSetter initialFocusSetter;

  /// Receives the [SessionShellContext].
  final UserLogoutter userLogoutter;

  /// Called when the context updates.
  final void Function(Map<String, String> context) onContextUpdated;

  /// Called when the user information changes
  final void Function(String userName, String userImageUrl) onUserUpdated;

  /// The list of context topics to listen for changes to.
  final List<String> contextTopics;

  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();

  final FocusRequestWatcherBinding _focusRequestWatcherBinding =
      new FocusRequestWatcherBinding();

  final HomeWorkProposer _homeWorkProposer = new HomeWorkProposer();

  final ActiveAgentsManager _activeAgentsManager = new ActiveAgentsManager();

  final WallpaperChooser _wallpaperChooser;

  /// Called when the [SessionShell] stops.
  final void Function() onSessionShellStopped;

  /// Allows control over various presentation parameters, such as lighting.
  final PresentationProxy _presentation = new PresentationProxy();

  /// Constructor.
  ArmadilloSessionShellModel({
    StartupContext startupContext,
    this.storyProviderStoryGenerator,
    this.suggestionProviderSuggestionModel,
    this.focusRequestWatcher,
    this.initialFocusSetter,
    this.userLogoutter,
    this.onContextUpdated,
    this.onUserUpdated,
    this.contextTopics = const <String>[],
    this.onSessionShellStopped,
    ValueChanged<List<String>> onWallpaperChosen,
  })  : _wallpaperChooser = new WallpaperChooser(
          onWallpaperChosen: onWallpaperChosen,
        ),
        super(startupContext: startupContext);

  @override
  void onReady(
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
  ) {
    super.onReady(
      sessionShellContext,
      focusProvider,
      focusController,
      visibleStoriesController,
      storyProvider,
      suggestionProvider,
      contextReader,
      contextWriter,
      intelligenceServices,
      link,
    );

    sessionShellContext.getPresentation(_presentation.ctrl.request());

    userLogoutter.sessionShellContext = sessionShellContext;
    focusController.watchRequest(
      _focusRequestWatcherBinding.wrap(focusRequestWatcher),
    );
    initialFocusSetter.focusProvider = focusProvider;
    storyProviderStoryGenerator
      ..link = link
      ..storyProvider = storyProvider;

    suggestionProviderSuggestionModel.suggestionProvider = suggestionProvider;

    ContextQuery query =
        // ignore: prefer_const_constructors
        new ContextQuery(selector: <ContextQueryEntry>[]);
    for (String topic in contextTopics) {
      ContextSelector selector = new ContextSelector(
          type: ContextValueType.entity,
          meta: new ContextMetadata(entity: new EntityMetadata(topic: topic)));
      query.selector.add(new ContextQueryEntry(key: topic, value: selector));
    }
    contextReader.subscribe(
      query,
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(onContextUpdated),
      ),
    );
    sessionShellContext.getAccount((Account account) {
      if (account == null) {
        onUserUpdated?.call('Guest', null);
      } else {
        onUserUpdated?.call(account.displayName, account.imageUrl);
      }
    });

    _homeWorkProposer.start(contextReader, intelligenceServices);

    _activeAgentsManager.start(
      sessionShellContext,
      focusProvider,
      storyProvider,
      intelligenceServices,
    );

    _wallpaperChooser.start(
      focusProvider,
      storyProvider,
      intelligenceServices,
      link,
    );
  }

  @override
  void onStop() {
    _activeAgentsManager.stop();
    _wallpaperChooser.stop();
    _homeWorkProposer.stop();
    _contextListenerBinding.close();
    _focusRequestWatcherBinding.close();
    _presentation.ctrl.close();
    suggestionProviderSuggestionModel.close();
    storyProviderStoryGenerator.close();
    onSessionShellStopped?.call();
    super.onStop();
  }

  @override
  void onNotify(String json) {
    storyProviderStoryGenerator.onLinkChanged(json);
    _wallpaperChooser.onLinkChanged(json);
  }

  /// Called when the user context is tapped.
  void onUserContextTapped() {
    _currentLocation = _nextLocation;
    contextWriter.writeEntityTopic(_kLocationTopic, _currentJsonLocation);
  }

  String get _currentJsonLocation => '{"location":"$_currentLocation"}';
  String _currentLocation = 'unknown';
  String get _nextLocation {
    switch (_currentLocation) {
      case 'home':
        return 'unknown';
      case 'work':
        return 'home';
      default:
        return 'work';
    }
  }
}

class _ContextListenerImpl extends ContextListener {
  final void Function(Map<String, String> context) onContextUpdated;

  _ContextListenerImpl(this.onContextUpdated);

  @override
  void onContextUpdate(ContextUpdate update) {
    Map<String, String> values = <String, String>{};
    for (final ContextUpdateEntry entry in update.values) {
      if (entry.value.isEmpty) {
        continue;
      }
      // TODO(thatguy): The context engine can return multiple entries for a
      // given selector (in this case topics). The API doesn't make it easy to
      // get the one "authoritative" value for a topic (since that doesn't
      // really exist), so we just take the first value for now.
      values[entry.key] = entry.value[0].content;
    }

    onContextUpdated?.call(values);
  }
}
