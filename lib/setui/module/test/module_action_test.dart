// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_module/module_action.dart';
import 'package:lib_setui_module/module_blueprint.dart';
import 'package:lib_setui_module/module_action_result_sender.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// TODO: Refactor this class to use the new SDK instead of deprecated API
// ignore: deprecated_member_use
class MockDriver extends Mock implements ModuleDriver {}

class MockStream extends Mock implements Stream<String> {}

class MockActionResultReceiver extends Mock implements ActionResultReceiver {}

/// Invoked when the action has completed.
typedef ResultCallback = void Function(String resultCode);

const String testResult = 'test_result';

void main() {
  test('test_launch', () {
    final MockDriver driver = new MockDriver();
    final ModuleBlueprint blueprint =
        new ModuleBlueprint('foo', 'bar', 'test', driver);
    final Step step = new Step('start', 'foo');

    final MockStream stream = new MockStream();
    final MockActionResultReceiver callback = new MockActionResultReceiver();
    final ModuleAction action = new ModuleAction(step, blueprint, callback);

    // Return mock stream when asked to watch link. This should be done in
    // launch so must come before.
    when(driver.watch(action.linkKey, any, all: anyNamed('all')))
        .thenAnswer((_) => stream);

    // Launch handler.
    action.launch();

    // Verify that we are listening to the link and capture callback.
    ResultCallback resultCallback =
        verify(stream.listen(captureAny)).captured.single;

    // Capture intent passed in.
    final Intent intent = verify(driver.embedModule(
            name: anyNamed('name'), intent: captureAnyNamed('intent')))
        .captured
        .single;

    // Verify verb and handler match.
    expect(intent.action, action.blueprint.verb);
    expect(intent.handler, action.blueprint.handler);

    // Search for link and make sure correctly set to destination link name.
    bool linkFound = false;
    for (IntentParameter param in intent.parameters) {
      if (param.name == action.linkKey) {
        linkFound = true;
        expect(param.data.linkName, stepResultLinkName);
      }
    }

    // Verify link was found.
    expect(linkFound, true);

    // Invoke the callback.
    resultCallback(testResult);

    // Make sure change is propagated back
    expect(
        verify(callback.onResult(captureAny)).captured.single.code, testResult);
  });

  test('test_sender', () {
    final MockDriver driver = new MockDriver();
    new ModuleActionResultSender(driver).sendResult(testResult);

    // Ensure module driver receives result from sender.
    verify(driver.put(stepResultLinkName, testResult, any));
  });
}
