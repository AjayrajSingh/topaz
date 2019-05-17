// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ui_input/fidl_async.dart'
    show KeyboardEvent, KeyboardEventPhase, kModifierLeftAlt;
import 'package:fidl_fuchsia_ui_policy/fidl_async.dart'
    show
        KeyboardCaptureListenerHack,
        KeyboardCaptureListenerHackProxy,
        Presentation;

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:lib.story_shell/common.dart';

/// Test keyevents are triggering callbacks
/// This needs to run on Fuchsia because we are using real InterfaceHandles
class MockPresentation extends Mock implements Presentation {
  KeyboardEvent _eventToCapture;
  final KeyboardCaptureListenerHackProxy _proxy =
      KeyboardCaptureListenerHackProxy();
  @override
  Future<void> captureKeyboardEventHack(KeyboardEvent eventToCapture,
      InterfaceHandle<KeyboardCaptureListenerHack> listener) async {
    _eventToCapture = eventToCapture;
    _proxy.ctrl.bind(listener);
  }

  void triggerEvent() {
    _proxy.onEvent(_eventToCapture);
  }
}

// Test class for capturing if callbacks are being called correctly
class CallbackTest {
  bool _called = false;

  /// Has this been called.
  bool get called => _called;

  /// We will give this as the callback to check if the event listener is
  /// correctly calling on events
  void call() {
    _called = true;
  }
}

void main() {
  KeyboardEvent _upperCaseQ;
  KeyboardEvent _lAltT;

  setUp(() {
    _lAltT = KeyboardEvent(
        codePoint: ascii.encode('T')[0],
        hidUsage: 0,
        eventTime: 0,
        deviceId: 0,
        modifiers: kModifierLeftAlt,
        phase: KeyboardEventPhase.pressed);

    _upperCaseQ = KeyboardEvent(
        codePoint: ascii.encode('Q')[0],
        hidUsage: 0,
        eventTime: 0,
        deviceId: 0,
        modifiers: 0,
        phase: KeyboardEventPhase.pressed);
  });

  /// Test registering and unregistering keyevent/callback pairs
  group('Single event registered:', () {
    test('registerKeyboardEventCallback registers the pair with KeyListener',
        () {
      KeyListener keyListener = KeyListener();
      void callbackA() => null;
      keyListener.registerKeyboardEventCallback(
          event: _upperCaseQ, callback: callbackA);
      expect(keyListener.registeredEvents[_upperCaseQ], contains(callbackA));
    });
    test('event is triggered by corresponding KeyEvent:', () async {
      KeyListener keyListener = KeyListener();
      CallbackTest test = CallbackTest();
      MockPresentation mockPresentation = MockPresentation();
      keyListener.registerKeyboardEventCallback(
          event: _upperCaseQ, callback: test.call);
      expect(keyListener.registeredEvents[_upperCaseQ], contains(test.call));
      // This will automatically call captureKeyboardEventHack() on all
      // registered events, wrapping the listener in an InterfaceHandle.
      // The mock class has overridden this.
      keyListener.listen(mockPresentation);
      // Trigger the registered event, which should call the callback
      mockPresentation.triggerEvent();
      // give the call time to propagate
      Future sleep1() {
        return Future.delayed(const Duration(seconds: 1), () {});
      }

      await sleep1();
      expect(test.called, true);
    });
  });

  group('Multiple events registered:', () {
    test('registerKeyboardEventCallback registers two pairs with KeyListener',
        () {
      KeyListener keyListener = KeyListener();
      void callbackA() => 'A';
      keyListener.registerKeyboardEventCallback(
          event: _upperCaseQ, callback: callbackA);
      void callbackB() => 'B';
      keyListener.registerKeyboardEventCallback(
          event: _lAltT, callback: callbackB);
      expect(keyListener.registeredEvents[_upperCaseQ], contains(callbackA));
      expect(keyListener.registeredEvents[_lAltT], contains(callbackB));
    });
  });
}
