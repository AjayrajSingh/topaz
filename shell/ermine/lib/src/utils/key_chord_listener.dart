// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show ascii;
import 'dart:ui' show VoidCallback;

import 'package:fidl_fuchsia_ui_policy/fidl_async.dart'
    show
        KeyboardCaptureListenerHack,
        KeyboardCaptureListenerHackBinding,
        Presentation;
import 'package:fidl_fuchsia_ui_input/fidl_async.dart';

/// Listens for key chords and triggers its callbacks when they occur.
class KeyChordListener extends KeyboardCaptureListenerHack {
  final VoidCallback onMeta;
  final VoidCallback onFullscreen;
  final VoidCallback onCancel;
  final VoidCallback onLogout;

  // Key chords that the session shell listens to and the function to call
  // when the key is pressed.
  final _keyChords = <KeyboardEvent, void Function(KeyChordListener)>{
    // Left Alt + Space bar.
    KeyboardEvent(
      deviceId: 0,
      eventTime: 0,
      hidUsage: 0,
      codePoint: ascii.encode(' ')[0],
      modifiers: kModifierLeftAlt,
      phase: KeyboardEventPhase.pressed,
    ): (listener) {
      listener.onMeta?.call();
    },
    // Right Alt + Lower case f.
    KeyboardEvent(
      deviceId: 0,
      eventTime: 0,
      hidUsage: 0,
      codePoint: ascii.encode('f')[0],
      modifiers: kModifierRightAlt,
      phase: KeyboardEventPhase.pressed,
    ): (listener) {
      listener.onFullscreen?.call();
    },
    // Lower case o + Right Alt.
    KeyboardEvent(
      deviceId: 0,
      eventTime: 0,
      hidUsage: 0,
      codePoint: ascii.encode('o')[0],
      modifiers: kModifierRightAlt,
      phase: KeyboardEventPhase.pressed,
    ): (listener) {
      listener.onLogout?.call();
    },
    // Esc key.
    KeyboardEvent(
      deviceId: 0,
      eventTime: 0,
      hidUsage: 41,
      codePoint: 0,
      modifiers: 0,
      phase: KeyboardEventPhase.pressed,
    ): (listener) {
      listener.onCancel?.call();
    }
  };

  final _keyListenerBindings = <KeyboardCaptureListenerHackBinding>[];

  KeyChordListener({
    this.onMeta,
    this.onFullscreen,
    this.onLogout,
    this.onCancel,
  });

  /// Starts listening to key chords.
  void listen(Presentation presentation) {
    for (final chords in _keyChords.entries) {
      final binding = KeyboardCaptureListenerHackBinding();
      presentation.captureKeyboardEventHack(chords.key, binding.wrap(this));
      _keyListenerBindings.add(binding);
    }
  }

  /// |KeyboardCaptureListenerHack|.
  @override
  Future<void> onEvent(KeyboardEvent event) async {
    for (final chords in _keyChords.entries) {
      final key = chords.key;
      if (key.codePoint == event.codePoint) {
        if (key.modifiers > 0) {
          if (key.modifiers & event.modifiers != 0) {
            chords.value?.call(this);
          }
        } else {
          chords.value?.call(this);
        }
        break;
      }
    }
  }
}
