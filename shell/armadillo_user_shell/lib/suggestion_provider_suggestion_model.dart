// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.suggestion.fidl/speech_to_text.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/suggestion_display.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/user_input.fidl.dart' as maxwell;
import 'package:lib.user.fidl/focus.fidl.dart';
import 'package:armadillo/interruption_overlay.dart';
import 'package:armadillo/story.dart';
import 'package:armadillo/story_cluster.dart';
import 'package:armadillo/story_cluster_id.dart';
import 'package:armadillo/story_model.dart';
import 'package:armadillo/suggestion.dart';
import 'package:armadillo/suggestion_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

import 'hit_test_model.dart';

const int _kMaxSuggestions = 100;

/// Listens to a maxwell suggestion list.  As suggestions change it
/// notifies its [suggestionListener].
class MaxwellSuggestionListenerImpl extends maxwell.SuggestionListener {
  /// String prefix
  final String prefix;

  /// Listener that is called when list of suggestions update
  final VoidCallback suggestionListener;

  /// Listener that is called when list of interruptions update
  final _InterruptionListener interruptionListener;

  /// If true, downgrade interruptions
  final bool downgradeInterruptions;

  final List<Suggestion> _suggestions = <Suggestion>[];
  final List<Suggestion> _interruptions = <Suggestion>[];

  /// Constructor
  MaxwellSuggestionListenerImpl({
    this.prefix,
    this.suggestionListener,
    this.interruptionListener,
    this.downgradeInterruptions: false,
  });

  /// List of suggestions
  List<Suggestion> get suggestions => _suggestions.toList();

  /// List of interruptions
  List<Suggestion> get interruptions => _interruptions.toList();

  @override
  void onAdd(List<maxwell.Suggestion> suggestions) {
    log.fine('$prefix onAdd $suggestions');
    for (maxwell.Suggestion suggestion in suggestions) {
      if (downgradeInterruptions ||
          suggestion.display.annoyance == maxwell.AnnoyanceType.none) {
        _suggestions.add(_convert(suggestion));
      } else {
        Suggestion interruption = _convert(suggestion);
        _interruptions.add(interruption);
        interruptionListener.onInterruptionAdded(interruption);
      }
    }
    suggestionListener?.call();
  }

  @override
  void onRemove(String uuid) {
    log.fine('$prefix onRemove $uuid');
    _suggestions.removeWhere(
      (Suggestion suggestion) => suggestion.id.value == uuid,
    );
    if (_interruptions
        .where((Suggestion suggestion) => suggestion.id.value == uuid)
        .isNotEmpty) {
      _interruptions.removeWhere(
        (Suggestion suggestion) => suggestion.id.value == uuid,
      );
      interruptionListener.onInterruptionRemoved(uuid);
    }
    suggestionListener?.call();
  }

  @override
  void onRemoveAll() {
    log.fine('$prefix onRemoveAll');
    clearSuggestions();
  }

  @override
  void onProcessingChange(bool processing) {
    // TODO(jwnichols): Incorporate this into the user interface somehow
  }

  /// Clear all suggestions
  void clearSuggestions() {
    List<Suggestion> interruptionsToRemove = _interruptions.toList();
    _interruptions.clear();
    for (Suggestion suggestion in interruptionsToRemove) {
      interruptionListener.onInterruptionRemoved(
        suggestion.id.value,
      );
    }
    _suggestions.clear();
    suggestionListener?.call();
  }
}

class _MaxwellTranscriptionListenerImpl extends maxwell.TranscriptionListener {
  final VoidCallback onReadyImpl;
  final ValueChanged<String> onTranscriptUpdateImpl;
  final VoidCallback onErrorImpl;

  _MaxwellTranscriptionListenerImpl({
    this.onReadyImpl,
    this.onTranscriptUpdateImpl,
    this.onErrorImpl,
  });

  @override
  void onReady() {
    log.fine('onReady');
    onReadyImpl?.call();
  }

  @override
  void onTranscriptUpdate(String spokenText) {
    log.fine('spokenText $spokenText');
    onTranscriptUpdateImpl?.call(spokenText);
  }

  @override
  void onError() {
    log.fine('onError');
    onErrorImpl?.call();
  }
}

class _MaxwellFeedbackListenerImpl extends maxwell.FeedbackListener {
  final ValueChanged<String> onTextResponseImpl;
  final ValueChanged<maxwell.SpeechStatus> onStatusChangedImpl;

  _MaxwellFeedbackListenerImpl({
    this.onTextResponseImpl,
    this.onStatusChangedImpl,
  });

  @override
  void onStatusChanged(maxwell.SpeechStatus status) {
    log.info('Status changed: $status');
    onStatusChangedImpl?.call(status);
  }

  @override
  void onTextResponse(String responseText) {
    log.fine('responseText $responseText');
    onTextResponseImpl?.call(responseText);
  }
}

/// Called when an interruption occurs.
typedef void OnInterruptionAdded(Suggestion interruption);

/// Called when an interruption has been removed.
typedef void OnInterruptionRemoved(String id);

/// Called when all interruptions are removed.
typedef void OnInterruptionsRemoved();

/// Listens for interruptions from maxwell.
class _InterruptionListener extends maxwell.SuggestionListener {
  /// Called when an interruption occurs.
  final OnInterruptionAdded onInterruptionAdded;

  /// Called when an interruption is finished.
  final OnInterruptionRemoved onInterruptionRemoved;

  /// Called when all interruptions are finished.
  final VoidCallback onInterruptionsRemoved;

  /// Constructor.
  _InterruptionListener({
    @required this.onInterruptionAdded,
    @required this.onInterruptionRemoved,
    @required this.onInterruptionsRemoved,
  });

  @override
  void onAdd(List<maxwell.Suggestion> suggestions) {
    for (maxwell.Suggestion suggestion in suggestions) {
      onInterruptionAdded(_convert(suggestion));
    }
  }

  @override
  void onRemove(String uuid) {
    // TODO(apwilson): decide what to do with a removed interruption.
    onInterruptionRemoved(uuid);
  }

  @override
  void onRemoveAll() {
    // TODO(apwilson): decide what to do with a removed interruption.
    onInterruptionsRemoved();
  }

  @override
  void onProcessingChange(bool processing) {
    // TODO(jwnichols): This method doesn't make sense for interruptions and
    // will go away once we create a specialized listener for interruptions
  }
}

Suggestion _convert(maxwell.Suggestion suggestion) {
  return new Suggestion(
    id: new SuggestionId(suggestion.uuid),
    title: suggestion.display.headline,
    description: suggestion.display.subheadline,
    themeColor: new Color(suggestion.display.color),
    selectionType: SelectionType.launchStory,
    imageUrl: suggestion.display.imageUrl,
    imageType:
        suggestion.display.imageType == maxwell.SuggestionImageType.person
            ? ImageType.person
            : ImageType.other,
    iconUrls: suggestion.display.iconUrls,
    confidence: suggestion.confidence,
  );
}

/// Creates a list of suggestions for the SuggestionList using the
/// [maxwell.SuggestionProvider].
class SuggestionProviderSuggestionModel extends SuggestionModel {
  final maxwell.SuggestionListenerBinding _askListenerBinding =
      new maxwell.SuggestionListenerBinding();

  // Listens for changes to maxwell's ask suggestion list.
  MaxwellSuggestionListenerImpl _askListener;

  final maxwell.SuggestionListenerBinding _nextListenerBinding =
      new maxwell.SuggestionListenerBinding();

  // Listens for changes to maxwell's next suggestion list.
  MaxwellSuggestionListenerImpl _nextListener;

  _InterruptionListener _interruptionListener;

  final List<Suggestion> _currentInterruptions = <Suggestion>[];

  final maxwell.FeedbackListenerBinding _feedbackListenerBinding =
      new maxwell.FeedbackListenerBinding();

  // Listens for changes in conversational state. This is temporary; see
  // comments in suggestion_provider.fidl.
  _MaxwellFeedbackListenerImpl _feedbackListener;

  final maxwell.TranscriptionListenerBinding _transcriptionListenerBinding =
      new maxwell.TranscriptionListenerBinding();

  /// When the user is asking via text or voice we want to show the maxwell ask
  /// suggestions rather than the normal maxwell suggestion list.
  String _askText;
  bool _asking = false;
  bool _processingAsk = false;
  bool _speaking = false;

  /// Set from an external source - typically the UserShell.
  maxwell.SuggestionProviderProxy _suggestionProviderProxy;

  /// Set from an external source - typically the UserShell.
  FocusControllerProxy _focusController;

  /// Set from an external source - typically the UserShell.
  VisibleStoriesControllerProxy _visibleStoriesController;

  // Set from an external source - typically the UserShell.
  StoryModel _storyModel;

  StoryClusterId _lastFocusedStoryClusterId;

  final Set<VoidCallback> _focusLossListeners = new Set<VoidCallback>();

  /// Listens for changes to visible stories.
  final HitTestModel hitTestModel;

  /// Called when an interruption is added.
  final OnInterruptionAdded onInterruptionAdded;

  /// Called when an interruption is removed.
  final OnInterruptionRemoved onInterruptionRemoved;

  /// Called when all interruptions are removed.
  final OnInterruptionsRemoved onInterruptionsRemoved;

  final Set<maxwell.SuggestionListenerBinding> _askListenerBindings =
      new Set<maxwell.SuggestionListenerBinding>();

  /// Constructor.
  SuggestionProviderSuggestionModel({
    this.hitTestModel,
    this.onInterruptionAdded,
    this.onInterruptionRemoved,
    this.onInterruptionsRemoved,
  });

  /// Call to close all the handles opened by this model.
  void close() {
    if (_askListenerBinding.isBound) {
      _askListenerBinding.close();
    }
    _nextListenerBinding.close();
    _feedbackListenerBinding.close();
    _transcriptionListenerBinding.close();
    for (maxwell.SuggestionListenerBinding askListener
        in _askListenerBindings) {
      askListener.close();
    }
  }

  /// Dataflow spaghetti.
  maxwell.SuggestionProviderProxy get suggestionProviderProxy =>
      _suggestionProviderProxy;

  /// Setting [suggestionProvider] triggers the loading on suggestions.
  /// This is typically set by the UserShell.
  set suggestionProvider(
    maxwell.SuggestionProviderProxy suggestionProviderProxy,
  ) {
    _suggestionProviderProxy = suggestionProviderProxy;
    _interruptionListener = new _InterruptionListener(
      onInterruptionAdded: onInterruptionAdded,
      onInterruptionRemoved: _onInterruptionRemoved,
      onInterruptionsRemoved: _onInterruptionsRemoved,
    );
    _askListener = new MaxwellSuggestionListenerImpl(
      prefix: 'ask',
      suggestionListener: _onAskSuggestionsChanged,
      interruptionListener: _interruptionListener,
      downgradeInterruptions: true,
    );
    _nextListener = new MaxwellSuggestionListenerImpl(
      prefix: 'next',
      suggestionListener: _onNextSuggestionsChanged,
      interruptionListener: _interruptionListener,
    );
    _feedbackListener = new _MaxwellFeedbackListenerImpl(
      onTextResponseImpl: (String text) {},
      onStatusChangedImpl: (maxwell.SpeechStatus speechStatus) {
        switch (speechStatus) {
          case maxwell.SpeechStatus.processing:
            break;
          case maxwell.SpeechStatus.responding:
            _speaking = true;
            if (!_processingAsk) {
              _processingAsk = true;
            }
            notifyListeners();
            break;
          case maxwell.SpeechStatus.idle:
            _speaking = false;
            _processingAsk = false;
            notifyListeners();
            break;
          default:
            if (_processingAsk) {
              _processingAsk = false;
              notifyListeners();
            }
            break;
        }
      },
    );
    _load();
  }

  /// Sets the [FocusController] called when focus changes.
  set focusController(FocusControllerProxy focusController) {
    _focusController = focusController;
  }

  /// Sets the [VisibleStoriesController] called when the list of visible
  /// stories changes.
  set visibleStoriesController(
    VisibleStoriesControllerProxy visibleStoriesController,
  ) {
    _visibleStoriesController = visibleStoriesController;
  }

  /// Sets the [StoryModel] used to get the currently focused and visible
  /// stories.
  set storyModel(StoryModel storyModel) {
    _storyModel = storyModel;
    storyModel.addListener(_onStoryClusterListChanged);
  }

  /// [listener] will be called when no stories are in focus.
  void addOnFocusLossListener(VoidCallback listener) {
    _focusLossListeners.add(listener);
  }

  /// Called when an interruption is no longer showing.
  void onInterruptionDismissal(
    Suggestion interruption,
    DismissalReason reason,
  ) {
    // Ignore the interruption dismissal if its stale.
    switch (reason) {
      case DismissalReason.snoozed:
      case DismissalReason.timedOut:
        if (!_askListener.interruptions.contains(interruption) &&
            !_nextListener.interruptions.contains(interruption)) {
          return;
        }
        _currentInterruptions.insert(0, interruption);
        notifyListeners();
        break;
      default:
        break;
    }
  }

  /// Called when an interruption has been removed.
  void _onInterruptionRemoved(String uuid) {
    onInterruptionRemoved(uuid);
    _currentInterruptions.removeWhere(
      (Suggestion interruption) => interruption.id.value == uuid,
    );
    notifyListeners();
  }

  /// Called when an interruption has been removed.
  void _onInterruptionsRemoved() {
    onInterruptionsRemoved();
    _currentInterruptions.clear();
    notifyListeners();
  }

  void _load() {
    _suggestionProviderProxy
      ..subscribeToNext(
        _nextListenerBinding.wrap(_nextListener),
        _kMaxSuggestions,
      )
      ..registerFeedbackListener(
          _feedbackListenerBinding.wrap(_feedbackListener));
  }

  @override
  List<Suggestion> get askSuggestions =>
      _askListener?.suggestions ?? <Suggestion>[];

  @override
  List<Suggestion> get nextSuggestions {
    List<Suggestion> suggestions = new List<Suggestion>.from(
      _currentInterruptions,
    )..addAll(_nextListener?.suggestions ?? <Suggestion>[]);
    return suggestions;
  }

  @override
  void onSuggestionSelected(Suggestion suggestion) {
    _suggestionProviderProxy.notifyInteraction(
      suggestion.id.value,
      new maxwell.Interaction()..type = maxwell.InteractionType.selected,
    );
  }

  @override
  set askText(String text) {
    if (_askText != text) {
      _askText = text;

      // If our existing binding is bound, close it.
      if (_askListenerBinding.isBound) {
        _askListenerBinding.close();
      }

      // Also clear any suggestions that the ask listener may have cached
      _askListener.clearSuggestions();

      // Make a query and rewrap the binding
      _suggestionProviderProxy.query(
        _askListenerBinding.wrap(_askListener),
        new maxwell.UserInput()..text = text ?? '',
        _kMaxSuggestions,
      );
    }
  }

  @override
  String get askText => _askText ?? '';

  @override
  set asking(bool asking) {
    if (_asking != asking) {
      _asking = asking;
      if (!_asking && _askListenerBinding.isBound) {
        _askListenerBinding.close();
      }
      notifyListeners();
    }
  }

  /// Performs an ask query.
  void performAskQuery({
    String text,
    maxwell.SuggestionListener askListener,
  }) {
    final maxwell.SuggestionListenerBinding askListenerBinding =
        new maxwell.SuggestionListenerBinding();
    _askListenerBindings.add(askListenerBinding);

    // Make a query and rewrap the binding
    _suggestionProviderProxy.query(
      askListenerBinding.wrap(askListener),
      new maxwell.UserInput()..text = text ?? '',
      _kMaxSuggestions,
    );
    askListenerBinding.onConnectionError = () {
      askListenerBinding.close();
      _askListenerBindings.remove(askListenerBinding);
    };
  }

  @override
  bool get asking => _asking;

  @override
  bool get processingAsk => _processingAsk;

  @override
  bool get speaking => _speaking;

  @override
  void beginSpeechCapture({
    OnTranscriptUpdate onTranscriptUpdate,
    VoidCallback onReady,
    VoidCallback onError,
    VoidCallback onCompleted,
  }) {
    _transcriptionListenerBinding.close();

    log.info('Begin speech capture!');
    _suggestionProviderProxy.beginSpeechCapture(
      _transcriptionListenerBinding.wrap(new _MaxwellTranscriptionListenerImpl(
        onReadyImpl: onReady,
        onTranscriptUpdateImpl: onTranscriptUpdate,
        onErrorImpl: onError,
      )),
    );

    // The voice input is completed when the transcriptListener is closed
    _transcriptionListenerBinding.onConnectionError = () {
      onCompleted?.call();
      _transcriptionListenerBinding.close;
    };
  }

  @override
  void storyClusterFocusChanged(StoryCluster storyCluster) {
    _lastFocusedStoryCluster?.removeStoryListListener(_onStoryListChanged);
    storyCluster?.addStoryListListener(_onStoryListChanged);
    _lastFocusedStoryClusterId = storyCluster?.id;
    _onStoryListChanged();
  }

  void _onStoryClusterListChanged() {
    if (_lastFocusedStoryClusterId != null) {
      if (_lastFocusedStoryCluster == null) {
        _lastFocusedStoryClusterId = null;
        _onStoryListChanged();
        for (VoidCallback listener in _focusLossListeners) {
          listener();
        }
      }
    }
  }

  void _onStoryListChanged() {
    _focusController.set(_lastFocusedStoryCluster?.focusedStoryId?.value);

    List<String> visibleStoryIds = _lastFocusedStoryCluster?.stories
            ?.map<String>((Story story) => story.id.value)
            ?.toList() ??
        <String>[];
    hitTestModel.onVisibleStoriesChanged(visibleStoryIds);
    _visibleStoriesController.set(visibleStoryIds);
  }

  StoryCluster get _lastFocusedStoryCluster =>
      _lastFocusedStoryClusterId == null
          ? null
          : _storyModel.storyClusterWithId(_lastFocusedStoryClusterId);

  void _onAskSuggestionsChanged() {
    if (_asking) {
      notifyListeners();
    }
  }

  void _onNextSuggestionsChanged() {
    if (!_asking) {
      notifyListeners();
    }
  }
}
