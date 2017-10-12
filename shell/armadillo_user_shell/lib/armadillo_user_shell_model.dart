// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.context.fidl/context_writer.fidl.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart';
import 'package:lib.auth.fidl.account/account.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';
import 'package:lib.ui.presentation.fidl/presentation.fidl.dart';
import 'package:lib.user.fidl/focus.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:flutter/widgets.dart';
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

typedef void _OnContextUpdated(Map<String, String> context);
typedef void _OnUserUpdated(String userName, String userImageUrl);
typedef void _OnStop();

/// Connects [UserShell]'s services to Armadillo's associated classes.
class ArmadilloUserShellModel extends UserShellModel {
  /// Receives the [StoryProvider].
  final StoryProviderStoryGenerator storyProviderStoryGenerator;

  /// Receives the [SuggestionProvider], [FocusController], and
  /// [VisibleStoriesController].
  final SuggestionProviderSuggestionModel suggestionProviderSuggestionModel;

  /// Watches the [FocusController].
  final FocusRequestWatcherImpl focusRequestWatcher;

  /// Receives the [FocusProvider].
  final InitialFocusSetter initialFocusSetter;

  /// Receives the [UserShellContext].
  final UserLogoutter userLogoutter;

  /// Called when the context updates.
  final _OnContextUpdated onContextUpdated;

  /// Called when the user information changes
  final _OnUserUpdated onUserUpdated;

  /// The list of context topics to listen for changes to.
  final List<String> contextTopics;

  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();

  final FocusRequestWatcherBinding _focusRequestWatcherBinding =
      new FocusRequestWatcherBinding();

  final HomeWorkProposer _homeWorkProposer = new HomeWorkProposer();

  final ActiveAgentsManager _activeAgentsManager = new ActiveAgentsManager();

  final WallpaperChooser _wallpaperChooser;

  /// Called when the [UserShell] stops.
  final _OnStop onUserShellStopped;

  /// Allows control over various presentation parameters, such as lighting.
  final PresentationProxy _presentation = new PresentationProxy();

  /// Constructor.
  ArmadilloUserShellModel({
    this.storyProviderStoryGenerator,
    this.suggestionProviderSuggestionModel,
    this.focusRequestWatcher,
    this.initialFocusSetter,
    this.userLogoutter,
    this.onContextUpdated,
    this.onUserUpdated,
    this.contextTopics: const <String>[],
    this.onUserShellStopped,
    ValueChanged<List<String>> onWallpaperChosen,
  })
      : _wallpaperChooser = new WallpaperChooser(
          onWallpaperChosen: onWallpaperChosen,
        );

  @override
  void onReady(
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
  ) {
    super.onReady(
      userShellContext,
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

    userShellContext.getPresentation(_presentation.ctrl.request());

    userLogoutter.userShellContext = userShellContext;
    focusController.watchRequest(
      _focusRequestWatcherBinding.wrap(focusRequestWatcher),
    );
    initialFocusSetter.focusProvider = focusProvider;
    storyProviderStoryGenerator
      ..link = link
      ..storyProvider = storyProvider;
    suggestionProviderSuggestionModel
      ..suggestionProvider = suggestionProvider
      ..focusController = focusController
      ..visibleStoriesController = visibleStoriesController;
    ContextQuery query = new ContextQuery()
      ..selector = <String, ContextSelector>{};
    for (String topic in contextTopics) {
      ContextSelector selector = new ContextSelector()
        ..type = ContextValueType.entity
        ..meta = new ContextMetadata();
      selector.meta.entity = new EntityMetadata();
      selector.meta.entity.topic = topic;
      query.selector[topic] = selector;
    }
    contextReader.subscribe(
      query,
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(onContextUpdated),
      ),
    );
    userShellContext.getAccount((Account account) {
      if (account == null) {
        onUserUpdated?.call('Guest', null);
      } else {
        onUserUpdated?.call(account.displayName, account.imageUrl);
      }
    });

    _homeWorkProposer.start(contextReader, intelligenceServices);

    _activeAgentsManager.start(
      userShellContext,
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
    onUserShellStopped?.call();
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
  final _OnContextUpdated onContextUpdated;

  _ContextListenerImpl(this.onContextUpdated);

  @override
  void onContextUpdate(ContextUpdate update) {
    Map<String, String> values = <String, String>{};
    for (String key in update.values.keys) {
      if (update.values[key].isEmpty) {
        return;
      }
      // TODO(thatguy): The context engine can return multiple entries for a
      // given selector (in this case topics). The API doesn't make it easy to
      // get the one "authoritative" value for a topic (since that doesn't
      // really exist), so we just take the first value for now.
      values[key] = update.values[key][0].content;
    }
    onContextUpdated?.call(values);
  }
}
