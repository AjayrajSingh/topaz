// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib_setiu_common/action_handler.dart';
import 'package:lib_setiu_common/step.dart';
import 'package:lib_setiu_module/module_action.dart';
import 'package:lib_setiu_module/module_action_handler.dart';
import 'package:lib_setiu_module/module_result_helper.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockDriver extends Mock implements ModuleDriver {}

class MockStream extends Mock implements Stream<dynamic> {}

class ResultCaptor {
  ActionResult result;

  //ignore: use_setters_to_change_properties
  void onResult(ActionResult result) {
    this.result = result;
  }
}

/// Invoked when the action has completed.
typedef ResultCallback = void Function(String resultCode);

const String testResult = 'test_result';

void main() {
  test('test_launch', () {
    final ModuleAction action = new ModuleAction('foo', 'bar', 'test');
    final Step step = new Step('start', 'foo');
    final MockDriver driver = new MockDriver();

    final MockStream stream = new MockStream();

    final ModuleActionHandler handler =
        new ModuleActionHandler(driver, step, action);

    final ResultCaptor captor = new ResultCaptor();

    // Return mock stream when asked to watch link. This should be done in
    // launch so must come before.
    when(driver.watch(handler.linkKey, any, all: anyNamed('all')))
        .thenAnswer((_) => stream);

    // Launch handler.
    handler.launch(captor.onResult);

    // Verify that we are listening to the link and capture callback.
    ResultCallback callback = verify(stream.listen(captureAny)).captured.single;

    // Capture intent passed in.
    final Intent intent = verify(driver.embedModule(
            name: anyNamed('name'), intent: captureAnyNamed('intent')))
        .captured
        .single;

    // Verify verb and handler match.
    expect(intent.action, action.verb);
    expect(intent.handler, action.handler);

    // Search for link and make sure correctly set to destination link name.
    bool linkFound = false;
    for (IntentParameter param in intent.parameters) {
      if (param.name == handler.linkKey) {
        linkFound = true;
        expect(param.data.linkName, stepResultLinkName);
      }
    }

    // Verify link was found.
    expect(linkFound, true);

    // Invoke the callback.
    callback(testResult);

    // Make sure change is propagated back
    expect(captor.result.code, testResult);
  });

  test('test_helper', () {
    final MockDriver driver = new MockDriver();
    new ModuleResultHelper(driver).sendResult(testResult);

    // Ensure module driver receives result from helper.
    verify(driver.put(stepResultLinkName, testResult, any));
  });
}
