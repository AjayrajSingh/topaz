// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/*
  In the absence of a guaranteed device-level provider of key events
  Story Shell should listen for its own events, independent of Session Shell 
  implementation. 
*/

import 'package:fidl_fuchsia_ui_input/fidl.dart' show KeyboardEvent;
import 'package:fidl_fuchsia_ui_policy/fidl.dart'
    show
        Presentation,
        KeyboardCaptureListenerHack,
        KeyboardCaptureListenerHackBinding;

/// Type for callbacks
typedef VoidCallback = void Function();

/// Listens for registered keyboard events and calls the associated callback
/// when triggered.
class KeyListener implements KeyboardCaptureListenerHack {
  /// Callback for when the overview toggle key event has happened
  Map<KeyboardEvent, List<VoidCallback>> registeredEvents =
      <KeyboardEvent, List<VoidCallback>>{};

  /// Keep the presentation so we can register keypresses added after listen()
  Presentation _presentation;

  /// Key event listener
  final KeyboardCaptureListenerHackBinding _keyEventListener =
      new KeyboardCaptureListenerHackBinding();

  /// Call to register a key event - callback pair. The pair will be added
  /// to a Map, multiple callbacks can be associated with the same key event.
  /// Registered key events are automatically listened for.
  void registerKeyboardEventCallback(
      {KeyboardEvent event, VoidCallback callback}) {
    List<VoidCallback> callbacks = registeredEvents.putIfAbsent(
        event, () => <VoidCallback>[])
      ..add(callback);
    registeredEvents[event] = callbacks;
    listen(_presentation);
  }

  /// Start listening for the keyboard events that have been registered
  void listen(Presentation presentation) {
    // cache the Presentation so we can register new events
    _presentation = presentation;
    for (KeyboardEvent ev in registeredEvents.keys) {
      _presentation?.captureKeyboardEventHack(
        ev,
        _keyEventListener.wrap(this),
      );
    }
  }

  /// Stop listening for keyboard events
  void stop() {
    _keyEventListener.close();
  }

  /// |KeyboardCaptureListenerHack|
  @override
  void onEvent(KeyboardEvent ev) {
    for (KeyboardEvent event in registeredEvents.keys) {
      if (ev.codePoint == event.codePoint &&
          ev.modifiers == event.modifiers &&
          ev.phase == event.phase) {
        for (VoidCallback callback in registeredEvents[event]) {
          callback.call();
        }
      }
    }
  }
}
