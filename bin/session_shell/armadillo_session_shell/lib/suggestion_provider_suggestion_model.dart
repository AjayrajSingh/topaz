// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:armadillo/next.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_images/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as maxwell;
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

import 'hit_test_model.dart';

const int _kMaxSuggestions = 100;

/// Timeout to wait after typing to perform an ask query
const Duration _kAskQueryTimeout = const Duration(milliseconds: 500);

/// Listens to a maxwell next suggestion list.  As suggestions change it
/// notifies its [suggestionListener].
class MaxwellNextListenerImpl extends maxwell.NextListener {
  /// String prefix
  final String prefix;

  /// Listener that is called when list of suggestions update
  final VoidCallback suggestionListener;

  /// Listener that is called when the processing status has changed
  final ValueChanged<bool> processingChangeListener;

  final List<Suggestion> _suggestions = <Suggestion>[];

  /// Constructor
  MaxwellNextListenerImpl({
    this.prefix,
    this.suggestionListener,
    this.processingChangeListener,
  });

  /// List of suggestions
  List<Suggestion> get suggestions => _suggestions.toList();

  @override
  void onNextResults(List<maxwell.Suggestion> suggestions) {
    _suggestions.clear();
    log.fine('$prefix onQueryResults $suggestions');
    for (maxwell.Suggestion suggestion in suggestions) {
      _suggestions.add(_convert(suggestion));
    }
    suggestionListener?.call();
  }

  @override
  void onProcessingChange(bool processing) {
    processingChangeListener?.call(processing);
  }
}

/// Listens to a maxwell query suggestion list.  As suggestions change it
/// notifies its [suggestionListener].
class MaxwellQueryListenerImpl extends maxwell.QueryListener {
  /// String prefix
  final String prefix;

  /// Listener that is called when list of suggestions update
  final VoidCallback suggestionListener;

  /// Listener that is called when the processing status has changed
  final VoidCallback queryCompleteListener;

  final List<Suggestion> _suggestions = <Suggestion>[];

  /// Constructor
  MaxwellQueryListenerImpl({
    this.prefix,
    this.suggestionListener,
    this.queryCompleteListener,
  });

  /// List of suggestions
  List<Suggestion> get suggestions => _suggestions.toList();

  /// Returns `true` if there are no suggestions.
  bool get isEmpty => _suggestions.isEmpty;

  @override
  void onQueryResults(List<maxwell.Suggestion> suggestions) {
    _suggestions.clear();
    log.fine('$prefix onQueryResults $suggestions');
    for (maxwell.Suggestion suggestion in suggestions) {
      _suggestions.add(_convert(suggestion));
    }
    suggestionListener?.call();
  }

  @override
  void onQueryComplete() {
    queryCompleteListener?.call();
  }

  /// Clears the suggestion list in preparation for a new query.
  void clear() => _suggestions.clear();
}

/// Called when an interruption occurs.
typedef OnInterruption = void Function(Suggestion interruption);

/// Listens for interruptions from maxwell.
class MaxwellInterruptionListenerImpl extends maxwell.InterruptionListener {
  /// Called when an interruption occurs.
  final OnInterruption onInterruption;

  /// Constructor.
  MaxwellInterruptionListenerImpl({
    @required this.onInterruption,
  });

  @override
  void onInterrupt(maxwell.Suggestion suggestion) {
    onInterruption(_convert(suggestion));
  }
}

Suggestion _convert(maxwell.Suggestion suggestion) {
  return new Suggestion(
    id: new SuggestionId(suggestion.uuid),
    title: suggestion.display.headline,
    description: suggestion.display.subheadline ?? '',
    themeColor: new Color(suggestion.display.color),
    selectionType: SelectionType.launchStory,
    image: suggestion.display.image == null
        ? null
        : suggestion.display.image.image,
    imageType: suggestion.display.image == null
        ? ImageType.other
        : suggestion.display.image.imageType ==
                maxwell.SuggestionImageType.person
            ? ImageType.person
            : ImageType.other,
    icons: suggestion.display.icons == null
        ? <EncodedImage>[]
        : suggestion.display.icons
            .map((maxwell.SuggestionDisplayImage image) => image.image)
            .toList(),
    confidence: suggestion.confidence,
  );
}

/// Creates a list of suggestions for the SuggestionList using the
/// [maxwell.SuggestionProvider].
class SuggestionProviderSuggestionModel extends SuggestionModel {
  final maxwell.QueryListenerBinding _askListenerBinding =
      new maxwell.QueryListenerBinding();

  // Listens for changes to maxwell's ask suggestion list.
  MaxwellQueryListenerImpl _askListener;

  final maxwell.NextListenerBinding _nextListenerBinding =
      new maxwell.NextListenerBinding();

  // Listens for changes to maxwell's next suggestion list.
  MaxwellNextListenerImpl _nextListener;

  final maxwell.InterruptionListenerBinding _interruptionListenerBinding =
      new maxwell.InterruptionListenerBinding();

  MaxwellInterruptionListenerImpl _interruptionListener;

  // TODO(jwnichols): Is this still needed?
  final List<Suggestion> _currentInterruptions = <Suggestion>[];

  /// When the user is asking via text or voice we want to show the maxwell ask
  /// suggestions rather than the normal maxwell suggestion list.
  String _askText;
  bool _asking = false;

  /// Set from an external source - typically the SessionShell.
  maxwell.SuggestionProviderProxy _suggestionProviderProxy;

  /// Listens for changes to visible stories.
  final HitTestModel hitTestModel;

  /// Called when an interruption occurs.
  final OnInterruption onInterruption;

  /// Timer that tracks the delay between ask text input and making the actual
  /// query.
  Timer _askTextTimer;

  /// Constructor.
  SuggestionProviderSuggestionModel({
    this.hitTestModel,
    this.onInterruption,
  });

  /// Call to close all the handles opened by this model.
  void close() {
    if (_askListenerBinding.isBound) {
      _askListenerBinding.close();
    }
    _nextListenerBinding.close();
    _interruptionListenerBinding.close();
  }

  /// Setting [suggestionProvider] triggers the loading on suggestions.
  /// This is typically set by the SessionShell.
  set suggestionProvider(
    maxwell.SuggestionProviderProxy suggestionProviderProxy,
  ) {
    _suggestionProviderProxy = suggestionProviderProxy;
    _interruptionListener = new MaxwellInterruptionListenerImpl(
      onInterruption: onInterruption,
    );
    _askListener = new MaxwellQueryListenerImpl(
      prefix: 'ask',
      suggestionListener: _onAskSuggestionsChanged,
      queryCompleteListener: () => _processingAsk = false,
    );
    _nextListener = new MaxwellNextListenerImpl(
      prefix: 'next',
      suggestionListener: _onNextSuggestionsChanged,
      processingChangeListener: (bool processing) =>
          _processingNext = processing,
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
        // TODO(jwnichols): Not sure we should persist interruptions
        _currentInterruptions.insert(0, interruption);
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _load() {
    _suggestionProviderProxy
      ..subscribeToNext(
        _nextListenerBinding.wrap(_nextListener),
        _kMaxSuggestions,
      )
      ..subscribeToInterruptions(
        _interruptionListenerBinding.wrap(_interruptionListener),
      );
  }

  @override
  List<Suggestion> get askSuggestions =>
      _askListener?.suggestions ?? <Suggestion>[];

  @override
  List<Suggestion> get nextSuggestions {
    // TODO(jwnichols): I'm not sure the session shell should be explicitly
    // displaying interruptions that timed out.
    List<Suggestion> suggestions = new List<Suggestion>.from(
      _currentInterruptions,
    )..addAll(_nextListener?.suggestions ?? <Suggestion>[]);
    return suggestions;
  }

  @override
  void onSuggestionSelected(Suggestion suggestion) {
    _suggestionProviderProxy.notifyInteraction(
      suggestion.id.value,
      const maxwell.Interaction(type: maxwell.InteractionType.selected),
    );
  }

  @override
  set askText(String text) {
    if (_askText != text) {
      _askText = text;

      if (!_askListener.isEmpty) {
        _askListener.clear();
        _onAskSuggestionsChanged();
      }

      /// A timer ensures that we don't make unneeded ask queries while the
      /// user is still typing/talking
      _askTextTimer?.cancel();
      _askTextTimer = new Timer(_kAskQueryTimeout, () {
        // If our existing binding is bound, close it.
        if (_askListenerBinding.isBound) {
          _askListenerBinding.close();
        }

        // Make a query and rewrap the binding
        _suggestionProviderProxy.query(
          _askListenerBinding.wrap(_askListener),
          new maxwell.UserInput(text: text ?? ''),
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

  bool _processingNext;

  @override
  bool get processingNext => _processingNext;

  void _onNextSuggestionsChanged() {
    if (!_asking) {
      notifyListeners();
    }
  }
}
