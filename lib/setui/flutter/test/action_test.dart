// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide State, Step;
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_flutter/widget_action.dart';
import 'package:lib_setui_flutter/widget_action_client.dart';
import 'package:lib_setui_flutter/widget_action_host.dart';
import 'package:lib_setui_flutter/widget_blueprint.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockStep extends Mock implements Step {}

class MockActionResultReceiver extends Mock implements ActionResultReceiver {}

class MockStateModel extends Mock implements ActionStateModel {}

class MockWidgetActionClient extends Mock implements WidgetActionClient {}

class MockBuildContext extends Mock implements BuildContext {}

class MockWidgetBlueprint extends Mock implements WidgetBlueprint {}

void main() {
  // Verifies that an action can be properly launched from the roster and
  // the reported result is propagated back
  test('test_lifecycle', () {
    const String testActionName = 'test_action';
    const String testResult = 'test_result';

    final MockWidgetActionClient client = MockWidgetActionClient();
    final MockStateModel stateModel = MockStateModel();

    final MockStep step = MockStep();
    final ActionResultReceiver resultReceiver = MockActionResultReceiver();
    final MockBuildContext context = MockBuildContext();

    // Create Blueprint
    ActionResultSender actionResultSender;

    final WidgetBlueprint blueprint =
        WidgetBlueprint(testActionName, 'testBlueprint', stateModel,
            (ActionResultSender sender) {
      actionResultSender = sender;
      return client;
    });

    // Reply back with start when asked about state.
    when(client.state).thenReturn(State.started);

    blueprint.assemble(step, resultReceiver).launch();

    // Ensure start was called
    verify(client.state = State.started);

    // launch action and make sure client built
    verify(stateModel.setCurrentAction(captureAny))
        .captured
        .single
        .build(context);
    verify(client.build(context));

    reset(client);

    // Send result and verify received by ActionResultReceiver
    actionResultSender.sendResult(testResult);
    expect(verify(resultReceiver.onResult(captureAny)).captured.single.code,
        testResult);
    verify(client.state = State.finished);
  });

  test('test_host', () {
    // Ensures that the action host returns a widget even without state.
    expect(
        null !=
            WidgetActionHost().getWidget(MockStateModel(), MockBuildContext()),
        true);
  });

  // Verifies that a client can finish (by sending result) when starting.
  test('test_finish_during_start', () {
    final MockWidgetActionClient client = MockWidgetActionClient();
    final MockStateModel stateModel = MockStateModel();
    final ActionResultReceiver resultReceiver = MockActionResultReceiver();

    ActionResultSender actionResultSender;

    when(client.state = State.started).thenAnswer((state) {
      actionResultSender.sendResult(null);
      return State.started;
    });

    final WidgetBlueprint blueprint =
        WidgetBlueprint('testActionName', 'testBlueprint', stateModel,
            (ActionResultSender sender) {
      actionResultSender = sender;
      return client;
    });

    WidgetAction(null, resultReceiver, blueprint).launch();

    verify(client.state = State.finished);
  });

  // Ensures BuildContext is passed through to the client.
  test('test_build_context_propagation', () {
    final MockStateModel stateModel = MockStateModel();
    final MockBuildContext context = MockBuildContext();
    final MockWidgetBlueprint blueprint = MockWidgetBlueprint();
    final MockWidgetActionClient client = MockWidgetActionClient();

    when(blueprint.model).thenReturn(stateModel);
    when(blueprint.createClient).thenReturn((sender) => client);

    final WidgetAction action =
        WidgetAction(null, MockActionResultReceiver(), blueprint);
    when(stateModel.currentAction).thenReturn(action);

    action.launch();

    WidgetActionHost().getWidget(stateModel, context);

    expect(verify(client.build(captureAny)).captured.single, context);
  });
}
