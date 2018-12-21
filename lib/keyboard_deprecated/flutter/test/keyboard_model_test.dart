// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' show Random;

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:topaz.lib.keyboard_deprecated.dart/keyboard_display.dart';
import 'package:topaz.lib.keyboard_deprecated.flutter/keyboard.dart';
import 'package:topaz.lib.shell/models/overlay_position_model.dart';

class MockKeyboardDisplay extends Mock implements KeyboardDisplay {}

class MockOverlayPositionModel extends Mock implements OverlayPositionModel {}

void main() {
  group('keyboardModel', () {
    MockKeyboardDisplay keyboardDisplay;
    KeyboardModel model;

    setUp(() {
      keyboardDisplay = MockKeyboardDisplay();
      model = KeyboardModel(
        keyboardDisplay,
        overlayPositionModel: MockOverlayPositionModel(),
      );
    });

    test('testGetVisible', () {
      final bool isVisible = Random().nextBool();
      // Make sure isVisible is passed through.
      when(keyboardDisplay.keyboardVisible).thenReturn(isVisible);
      expect(model.keyboardVisible, isVisible);
    });

    test('testPropagation', () async {
      const isVisible = true;
      when(keyboardDisplay.keyboardVisible).thenReturn(isVisible);
      void Function(bool val) listenMethod =
          verify(keyboardDisplay.addListener(captureAny)).captured.single;

      int notificationCount = 0;

      // Use a listener to keep track of when policy model notifies.
      model.addListener(() {
        notificationCount++;
      });

      // Invoke callback passed by model to display for events.
      listenMethod(isVisible);

      // Needed to make sure notification is propagated through
      // [Model#notifyListeners].
      await Future<Null>.delayed(const Duration(seconds: 0));

      // Verify notification occurred.
      expect(notificationCount, 1);
    });
  });
}
