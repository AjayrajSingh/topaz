// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;

import 'package:lib.display.dart/display.dart';
import 'package:lib.display.flutter/display_policy_brightness_model.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  test('testGetBrightness', () {
    final Display display = MockDisplay();
    final DisplayPolicyBrightnessModel model =
        DisplayPolicyBrightnessModel(display);

    final double brightness = Random().nextDouble();
    // Make sure brightness is passed through.
    when(display.brightness).thenReturn(brightness);
    expect(model.brightness, brightness);
  });

  test('testBrightnessSanitation', () {
    final Display display = MockDisplay();
    final DisplayPolicyBrightnessModel model =
        DisplayPolicyBrightnessModel(display);

    // When no brightness is available, 0 should be returned.
    expect(model.brightness, DisplayPolicyBrightnessModel.minLevel);

    // Make sure brightness is never reported below min.
    when(display.brightness)
        .thenReturn(DisplayPolicyBrightnessModel.minLevel - 0.1);
    expect(model.brightness, DisplayPolicyBrightnessModel.minLevel);

    // Make sure brightness is never reported above max.
    when(display.brightness)
        .thenReturn(DisplayPolicyBrightnessModel.maxLevel + 0.1);
    expect(model.brightness, DisplayPolicyBrightnessModel.maxLevel);
  });

  test('testPropagation', () async {
    final Display display = MockDisplay();
    final DisplayPolicyBrightnessModel model =
        DisplayPolicyBrightnessModel(display);
    void Function(double val) listenMethod =
        verify(display.addListener(captureAny)).captured.single;

    int notificationCount = 0;

    // Use a listener to keep track of when policy model notifies.
    model.addListener(() {
      notificationCount++;
    });

    // Invoke callback passed by model to display for events.
    listenMethod(1.0);

    // Needed to make sure notification is propagated through
    // [Model#notifyListeners].
    await Future<Null>.delayed(const Duration(seconds: 0));

    // Verify notification occurred.
    expect(notificationCount, 1);

    // Make sure brightness set on model reaches display.
    final double setBrightness = Random().nextDouble();
    model.brightness = setBrightness;
    expect(verify(display.setBrightness(captureAny)).captured.single,
        setBrightness);
  });
}

class MockDisplay extends Mock implements Display {}
