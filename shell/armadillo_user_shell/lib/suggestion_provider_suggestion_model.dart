// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:armadillo/next.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.suggestion.fidl/suggestion_display.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/user_input.fidl.dart' as maxwell;
import 'package:meta/meta.dart';

import 'hit_test_model.dart';

const int _kMaxSuggestions = 100;

/// Timeout to wait after typing to perform an ask query
const Duration _kAskQueryTimeout = const Duration(milliseconds: 500);

/// Listens to a maxwell suggestion list.  As suggestions change it
/// notifies its [suggestionListener].
class MaxwellSuggestionListenerImpl extends maxwell.SuggestionListener {
  /// String prefix
  final String prefix;

  /// Listener that is called when list of suggestions update
  final VoidCallback suggestionListener;

  /// Listener that is called when list of interruptions update
  final _InterruptionListener interruptionListener;

  /// Listener that is called when the processing status has changed
  final ValueChanged<bool> processingChangeListener;

  /// If true, downgrade interruptions
  final bool downgradeInterruptions;

  final List<Suggestion> _suggestions = <Suggestion>[];
  final List<Suggestion> _interruptions = <Suggestion>[];

  /// Constructor
  MaxwellSuggestionListenerImpl({
    this.prefix,
    this.suggestionListener,
    this.interruptionListener,
    this.processingChangeListener,
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
    processingChangeListener?.call(processing);
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

  /// When the user is asking via text or voice we want to show the maxwell ask
  /// suggestions rather than the normal maxwell suggestion list.
  String _askText;
  bool _asking = false;

  /// Set from an external source - typically the UserShell.
  maxwell.SuggestionProviderProxy _suggestionProviderProxy;

  /// Listens for changes to visible stories.
  final HitTestModel hitTestModel;

  /// Called when an interruption is added.
  final OnInterruptionAdded onInterruptionAdded;

  /// Called when an interruption is removed.
  final OnInterruptionRemoved onInterruptionRemoved;

  /// Called when all interruptions are removed.
  final OnInterruptionsRemoved onInterruptionsRemoved;

  /// Timer that tracks the delay between ask text input and making the actual
  /// query.
  Timer _askTextTimer;

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
  }

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
      processingChangeListener: (bool processing) =>
          _processingAsk = processing,
      downgradeInterruptions: true,
    );
    _nextListener = new MaxwellSuggestionListenerImpl(
      prefix: 'next',
      suggestionListener: _onNextSuggestionsChanged,
      interruptionListener: _interruptionListener,
    );
    _load();
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
      );
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

      /// A timer ensures that we don't make unneeded ask queries while the
      /// user is still typing/talking
      _askTextTimer?.cancel();
      _askTextTimer = new Timer(_kAskQueryTimeout, () {
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
      });
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

  @override
  bool get asking => _asking;

  bool _processingAsk;

  @override
  bool get processingAsk => _processingAsk;

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
