// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/next.dart';

import 'package:lib.logging/logging.dart';
import 'package:lib.suggestion.fidl/speech_to_text.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart' as maxwell;

class _MaxwellTranscriptionListenerImpl extends maxwell.TranscriptionListener {
  final MaxwellVoiceModel model;

  _MaxwellTranscriptionListenerImpl(this.model);

  @override
  void onReady() {
    model.state = VoiceState.listening;
  }

  @override
  void onTranscriptUpdate(String spokenText) {
    if (spokenText != null && spokenText.isNotEmpty) {
      model.state = VoiceState.userSpeaking;
    }
    if (model._transcription != spokenText) {
      model
        .._transcription = spokenText
        ..notifyListeners();
    }
  }

  @override
  void onError() {
    model.state = VoiceState.error;
  }
}

class _MaxwellFeedbackListenerImpl extends maxwell.FeedbackListener {
  final MaxwellVoiceModel model;

  _MaxwellFeedbackListenerImpl(this.model);

  @override
  void onStatusChanged(maxwell.SpeechStatus status) {
    switch (status) {
      case maxwell.SpeechStatus.processing:
        model._processing = true;
        break;
      case maxwell.SpeechStatus.responding:
        // HACK(rosswang): Right now, it's possible Maxwell may attempt to start
        // replying while speech capture is still active. For now, close speech
        // capture if that happens. Eventually we'll want to wait until we've
        // stopped capturing first.
        model._transcriptionListenerBinding.close();
        model.state = VoiceState.replying;
        break;
      case maxwell.SpeechStatus.idle:
        model._processing = false;
        break;
      default:
        log.warning('Unknown speech status $status');
        model._processing = false;
        break;
    }
  }

  @override
  void onTextResponse(String responseText) {
    log.fine('responseText $responseText');
  }
}

/// Tracks voice status from Maxwell.
///
/// On the implementation side, voice status is effectively a stack of boolean
/// states, multiple of which can potentially be true at the same time. The
/// topmost true state is the [VoiceState]:
///   [VoiceState.replying]?
///   [VoiceState.userSpeaking] / [VoiceState.listening]?
///   [VoiceState.loading]?
///   [VoiceState.error]? (cleared on next request)
/// otherwise, [VoiceState.passive].
class MaxwellVoiceModel extends VoiceModel {
  /// Set from an external source - typically the UserShell.
  maxwell.SuggestionProviderProxy _suggestionProviderProxy;

  _MaxwellFeedbackListenerImpl _feedbackListener;
  final maxwell.FeedbackListenerBinding _feedbackListenerBinding =
      new maxwell.FeedbackListenerBinding();

  _MaxwellTranscriptionListenerImpl _transcriptionListener;
  final maxwell.TranscriptionListenerBinding _transcriptionListenerBinding =
      new maxwell.TranscriptionListenerBinding();

  String _transcription = '';
  // The loading state is !isInput && _processing.
  bool _processingValue = false;

  /// Default constructor.
  MaxwellVoiceModel() {
    _feedbackListener = new _MaxwellFeedbackListenerImpl(this);
    _transcriptionListener = new _MaxwellTranscriptionListenerImpl(this);
  }

  bool get _processing => _processingValue;

  set _processing(bool value) {
    _processingValue = value;
    // Processing state transitions that happen while capture is active are
    // handled by _transcriptionListenerBinding.onConnectionError, so only
    // update if capture is inactive.
    if (!isInput) {
      if (value) {
        state = VoiceState.loading;
      } else if (state != VoiceState.error) {
        // error supercedes passive
        state = VoiceState.passive;
      }
    }
  }

  @override
  String get transcription => _transcription;

  /// Sets the [suggestionProvider] to use for speech services.
  /// This is typically set by the UserShell.
  set suggestionProvider(
    maxwell.SuggestionProviderProxy suggestionProviderProxy,
  ) {
    _suggestionProviderProxy = suggestionProviderProxy;
    suggestionProviderProxy.registerFeedbackListener(
        _feedbackListenerBinding.wrap(_feedbackListener));
  }

  /// Call to close all the handles opened by this model.
  void close() {
    _feedbackListenerBinding.close();
    _transcriptionListenerBinding.close();
  }

  /// Initiates speech capture.
  @override
  void beginSpeechCapture() {
    state = VoiceState.preparing;
    _transcriptionListenerBinding.close();
    _transcription = '';

    _suggestionProviderProxy.beginSpeechCapture(
        _transcriptionListenerBinding.wrap(_transcriptionListener));

    // The voice input is completed when the transcriptionListener is closed
    _transcriptionListenerBinding.onConnectionError = () {
      _transcriptionListenerBinding.close();
      if (_processing) {
        state = VoiceState.loading;
      } else if (state != VoiceState.replying && state != VoiceState.error) {
        state = VoiceState.passive;
      }
    };
  }
}
