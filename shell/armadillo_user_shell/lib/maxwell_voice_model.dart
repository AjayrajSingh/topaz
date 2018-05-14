// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/next.dart';

import 'package:fidl_modular/fidl.dart' as maxwell;
import 'package:fidl_speech/fidl.dart' as speech;
import 'package:lib.app.dart/logging.dart';

import 'maxwell_hotword.dart';

class _MaxwellTranscriptionListenerImpl extends speech.TranscriptionListener {
  final MaxwellVoiceModel model;

  _MaxwellTranscriptionListenerImpl(this.model);

  @override
  void onReady() => model._speechToText = VoiceState.listening;

  @override
  void onTranscriptUpdate(String spokenText) {
    if (spokenText != null && spokenText.isNotEmpty) {
      model._speechToText = VoiceState.userSpeaking;
    }
    if (model._transcription != spokenText) {
      model
        .._transcription = spokenText
        ..notifyListeners();
    }
  }

  @override
  void onSpeechLevelUpdate(double speechLevel) {
    // TODO(modsquad)
    log.info('Speech level: $speechLevel');
  }

  @override
  void onError() => model._error = true;
}

class _MaxwellFeedbackListenerImpl extends maxwell.FeedbackListener {
  final MaxwellVoiceModel model;

  _MaxwellFeedbackListenerImpl(this.model);

  @override
  void onStatusChanged(maxwell.SpeechStatus status) {
    switch (status) {
      case maxwell.SpeechStatus.processing:
        model
          .._loading = true
          .._replying = false;
        break;
      case maxwell.SpeechStatus.responding:
        // (loading status indeterminate/moot)
        model._replying = true;
        // HACK(rosswang): Right now, it's possible Maxwell may attempt to start
        // replying while speech capture is still active. For now, close speech
        // capture if that happens. Eventually we'll want to wait until we've
        // stopped capturing first.
        model._transcriptionListenerBinding.close();
        break;
      case maxwell.SpeechStatus.idle:
        model
          .._loading = false
          .._replying = false;
        break;
      default:
        log.warning('Unknown speech status $status');
        model
          .._loading = false
          .._replying = false;
        break;
    }
  }

  @override
  void onTextResponse(String responseText) =>
      log.fine('responseText $responseText');
}

class _MaxwellVoiceModelHotword extends MaxwellHotword {
  final MaxwellVoiceModel model;

  _MaxwellVoiceModelHotword(this.model);

  @override
  void onReady() {
    model._hotwordReady = true;
  }

  @override
  void onHotword() => model.beginSpeechCapture();

  @override
  void onError() {
    model._hotwordReady = false;
    // don't raise the error flag just yet; this may be recoverable
  }

  @override
  void onFatal() {
    model
      .._error = true
      .._hotwordReady = false;
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
///   [VoiceState.passive]? (hotword ready?)
/// otherwise, [VoiceState.initializing].
class MaxwellVoiceModel extends VoiceModel {
  /// Set from an external source - typically the UserShell.
  speech.SpeechToTextProxy _speechToTextProxy;

  _MaxwellFeedbackListenerImpl _feedbackListener;
  final maxwell.FeedbackListenerBinding _feedbackListenerBinding =
      new maxwell.FeedbackListenerBinding();

  _MaxwellTranscriptionListenerImpl _transcriptionListener;
  final speech.TranscriptionListenerBinding _transcriptionListenerBinding =
      new speech.TranscriptionListenerBinding();

  _MaxwellVoiceModelHotword _hotword;

  String _transcription = '';

  // state stack (see class docs)
  bool _isReplying = false;
  VoiceState _speechToTextState;
  bool _isLoading = false;
  bool _isError = false;
  bool _isHotwordReady = false;

  /// Default constructor.
  MaxwellVoiceModel() {
    _feedbackListener = new _MaxwellFeedbackListenerImpl(this);
    _transcriptionListener = new _MaxwellTranscriptionListenerImpl(this);
    (_hotword = new _MaxwellVoiceModelHotword(this)).start();
  }

  set _replying(bool value) {
    _isReplying = value;
    _updateState();
  }

  set _speechToText(VoiceState value) {
    _speechToTextState = value;
    _updateState();
  }

  set _loading(bool value) {
    _isLoading = value;
    _updateState();
  }

  set _error(bool value) {
    _isError = value;
    _updateState();
  }

  set _hotwordReady(bool value) {
    _isHotwordReady = value;
    _updateState();
  }

  void _updateState() {
    if (_isReplying) {
      super.state = VoiceState.replying;
    } else if (_speechToTextState != null) {
      super.state = _speechToTextState;
    } else if (_isLoading) {
      super.state = VoiceState.loading;
    } else if (_isError) {
      super.state = VoiceState.error;
    } else if (_isHotwordReady) {
      super.state = VoiceState.passive;
    } else {
      super.state = VoiceState.initializing;
    }

    if (isInput) {
      _hotword.stop();
      _isHotwordReady = false;
    } else {
      _hotword.start();
    }
  }

  @override
  @deprecated
  set state(VoiceState state) {
    throw new UnsupportedError('state is not writeable.');
  }

  @override
  String get transcription => _transcription;

  /// Sets the [suggestionProvider] to use for state feedback.
  /// This is typically set by the UserShell.
  set suggestionProvider(
    maxwell.SuggestionProviderProxy suggestionProviderProxy,
  ) {
    suggestionProviderProxy.registerFeedbackListener(
        _feedbackListenerBinding.wrap(_feedbackListener));
  }

  /// Sets the [speechToText] to use for speech services.
  /// This is typically set by the UserShell.
  set speechToText(
    speech.SpeechToTextProxy speechToTextProxy,
  ) {
    _hotword.speechToText = _speechToTextProxy = speechToTextProxy;
  }

  /// Call to close all the handles opened by this model.
  void close() {
    _feedbackListenerBinding.close();
    _transcriptionListenerBinding.close();
    _hotword.stop();
  }

  /// Initiates speech capture.
  @override
  void beginSpeechCapture() {
    _speechToText = VoiceState.preparing;
    _error = false;
    _transcriptionListenerBinding.close();
    _transcription = '';

    _speechToTextProxy.beginCapture(
        _transcriptionListenerBinding.wrap(_transcriptionListener));

    // The voice input is completed when the transcriptionListener is closed
    _transcriptionListenerBinding.onConnectionError = () {
      _transcriptionListenerBinding.close();
      _speechToText = null;
    };
  }
}
