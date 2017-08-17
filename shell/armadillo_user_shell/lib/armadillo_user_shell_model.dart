// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.context/context_reader.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_provider.fidl.dart';
import 'package:apps.modular.services.auth.account/account.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.story/story_provider.fidl.dart';
import 'package:apps.modular.services.user/focus.fidl.dart';
import 'package:apps.modular.services.user/user_shell.fidl.dart';
import 'package:home_work_agent_lib/home_work_proposer.dart';
import 'package:lib.widgets/modular.dart';

import 'focus_request_watcher_impl.dart';
import 'initial_focus_setter.dart';
import 'story_provider_story_generator.dart';
import 'suggestion_provider_suggestion_model.dart';
import 'user_logoutter.dart';

const String _kLocationTopic = '/location/home_work';

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

  final ContextListenerForTopicsBinding _contextListenerBinding =
      new ContextListenerForTopicsBinding();

  final FocusRequestWatcherBinding _focusRequestWatcherBinding =
      new FocusRequestWatcherBinding();

  final HomeWorkProposer _homeWorkProposer = new HomeWorkProposer();

  /// Called when the [UserShell] stops.
  final _OnStop onUserShellStopped;

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
  });

  @override
  void onReady(
    UserShellContext userShellContext,
    FocusProvider focusProvider,
    FocusController focusController,
    VisibleStoriesController visibleStoriesController,
    StoryProvider storyProvider,
    SuggestionProvider suggestionProvider,
    ContextReader contextReader,
    ContextPublisher contextPublisher,
    ProposalPublisher proposalPublisher,
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
      contextPublisher,
      proposalPublisher,
      link,
    );
    userLogoutter.userShellContext = userShellContext;
    focusController.watchRequest(
      _focusRequestWatcherBinding.wrap(focusRequestWatcher),
    );
    initialFocusSetter.focusProvider = focusProvider;
    storyProviderStoryGenerator.link = link;
    storyProviderStoryGenerator.storyProvider = storyProvider;
    suggestionProviderSuggestionModel.suggestionProvider = suggestionProvider;
    suggestionProviderSuggestionModel.focusController = focusController;
    suggestionProviderSuggestionModel.visibleStoriesController =
        visibleStoriesController;
    contextReader.subscribeToTopics(
      new ContextQueryForTopics()..topics = contextTopics,
      _contextListenerBinding.wrap(
        new _ContextListenerForTopicsImpl(onContextUpdated),
      ),
    );
    userShellContext.getAccount((Account account) {
      if (account == null) {
        onUserUpdated?.call('Guest', null);
      } else {
        onUserUpdated?.call(account.displayName, account.imageUrl);
      }
    });

    _homeWorkProposer.start(contextReader, proposalPublisher);
  }

  @override
  void onStop() {
    _homeWorkProposer.stop();
    _contextListenerBinding.close();
    _focusRequestWatcherBinding.close();
    suggestionProviderSuggestionModel.close();
    storyProviderStoryGenerator.close();
    onUserShellStopped?.call();
    super.onStop();
  }

  @override
  void onNotify(String json) {
    storyProviderStoryGenerator.onLinkChanged(json);
  }

  /// Called when the user context is tapped.
  void onUserContextTapped() {
    _currentLocation = _nextLocation;
    contextPublisher.publish(_kLocationTopic, _currentJsonLocation);
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

class _ContextListenerForTopicsImpl extends ContextListenerForTopics {
  final _OnContextUpdated onContextUpdated;

  _ContextListenerForTopicsImpl(this.onContextUpdated);

  @override
  void onUpdate(ContextUpdateForTopics result) {
    onContextUpdated?.call(result.values);
  }
}
