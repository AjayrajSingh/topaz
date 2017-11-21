// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// Various voice states for the voice flow
/// Most of the states are from:
/// https://knowledge-ux-prototyping.teams.x20web.corp.google.com/motion/tts_spec/index.html
enum VoiceState {
  /// The system is not yet ready to listen for a hotword.
  initializing,

  /// User has not said the hotword
  passive,

  /// User has said the hotword and the system is getting ready to receive
  /// input. This state may be skipped if the system supports preamble audio.
  preparing,

  /// User has said the hot word and the system is ready to recieve input.
  /// The user has not speaking at this point.
  listening,

  /// User is actively speaking
  userSpeaking,

  /// The user voice input has been captured and the current query is being
  /// processed.
  loading,

  /// System is performing a TTS reply back to user
  replying,

  /// Speech input has encountered an error.
  error,
}

/// The [VoiceModel] tracks the various states of voice I/O flow.
abstract class VoiceModel extends Model {
  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static VoiceModel of(BuildContext context) =>
      new ModelFinder<VoiceModel>().of(context);

  VoiceState _state = VoiceState.initializing;

  /// The current voice state.
  VoiceState get state => _state;

  /// Sets the current voice input state.
  set state(VoiceState state) {
    if (_state != state) {
      _state = state;
      notifyListeners();
    }
  }

  /// True if [state] is [VoiceState.preparing], [VoiceState.listening], or
  /// [VoiceState.userSpeaking].
  bool get isInput =>
      _state == VoiceState.preparing ||
      _state == VoiceState.listening ||
      _state == VoiceState.userSpeaking;

  /// Gets the spoken text for the current query.
  String get transcription;

  /// Initiates speech capture, transitioning to the [VoiceState.listening]
  /// state once ready.
  void beginSpeechCapture();
}
