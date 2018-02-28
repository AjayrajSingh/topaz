// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:home_work_agent/home_work_proposer.dart';
import 'package:lib.auth.fidl.account/account.fidl.dart';
import 'package:lib.context.fidl/context_writer.fidl.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.speech.fidl/speech_to_text.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';
import 'package:lib.suggestion.fidl._suggestion_provider/suggestion_provider.fidl.dart';
import 'package:lib.ui.presentation.fidl/presentation.fidl.dart';
import 'package:lib.user.fidl._focus/focus.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:lib.widgets/modular.dart';

import 'active_agents_manager.dart';
import 'focus_request_watcher_impl.dart';
import 'initial_focus_setter.dart';
import 'maxwell_hotword.dart';
import 'maxwell_voice_model.dart';
import 'rate_limited_retry.dart';
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

  /// Tracks speech UI state.
  final MaxwellVoiceModel maxwellVoiceModel;

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
    ApplicationContext applicationContext,
    this.storyProviderStoryGenerator,
    this.suggestionProviderSuggestionModel,
    this.maxwellVoiceModel,
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
        ),
        super(applicationContext: applicationContext);

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

    suggestionProviderSuggestionModel.suggestionProvider = suggestionProvider;
    maxwellVoiceModel.suggestionProvider = suggestionProvider;
    _attachSpeechToText();

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
    maxwellVoiceModel.close();
    _speechToText.ctrl.close();
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

  final SpeechToTextProxy _speechToText = new SpeechToTextProxy();
  final RateLimitedRetry _retry =
      new RateLimitedRetry(MaxwellHotword.kMaxRetry);

  void _attachSpeechToText() {
    userShellContext.getSpeechToText(_speechToText.ctrl.request());
    maxwellVoiceModel.speechToText = _speechToText;
    _speechToText.ctrl.onConnectionError = () {
      if (_retry.shouldRetry) {
        _attachSpeechToText();
      } else {
        log.warning(_retry.formatMessage(
            component: 'speech to text', feature: 'voice input'));
      }
    };
  }
}

class _ContextListenerImpl extends ContextListener {
  final _OnContextUpdated onContextUpdated;

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
